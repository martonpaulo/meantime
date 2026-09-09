#if DEBUG
import AppKit
import MeantimeKit

/// Debug-only fixture for the quit-with-drafts contract (issue #13). It drives
/// the production `SettingsWindowController`, `ClockEditingSession` and
/// `SettingsPreview` against an in-memory preference store, answering the Save
/// / Discard / Cancel prompts from a script instead of a person, and asserts
/// what was persisted and how many termination replies were sent.
@MainActor
enum QuitDraftsDiagnostic {
    private enum Answer { case save, discard, cancel }

    /// One isolated app-shaped world.
    private struct World {
        let preferences: Preferences
        let preview: SettingsPreview
        let session: ClockEditingSession
        let controller: SettingsWindowController
        let window: NSWindow
    }

    private static func makeWorld(clockAnswer: Answer, appearanceAnswer: Answer,
                                  prompts: inout [String]) -> World {
        let preferences = Preferences(store: EphemeralPreferenceStore())
        preferences.clocks = [WorldClock(timeZoneID: "Europe/Madrid", customLabel: "Saved")]
        let preview = SettingsPreview(preferences: preferences)
        let session = ClockEditingSession(preferences: preferences, settingsPreview: preview)
        let controller = SettingsWindowController(
            preferences: preferences, settingsPreview: preview, clockEditingSession: session,
            formatter: ClockFormatter(), updateManager: UpdateManager())

        // A real window, never ordered front, so the sheet host exists.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
                              styleMask: [.titled], backing: .buffered, defer: true)
        controller.attachForTesting(window: window)

        var recorded: [String] = []
        controller.confirmations = DraftConfirmations(
            clock: { _, session, completion in
                recorded.append("clock")
                switch clockAnswer {
                case .save: completion(session.save())
                case .discard: session.discardForExternalNavigation(); completion(true)
                case .cancel: completion(false)
                }
            },
            appearance: { _, preview, completion in
                recorded.append("appearance")
                switch appearanceAnswer {
                case .save: preview.saveAppearance(); completion(true)
                case .discard: preview.discardAppearance(); completion(true)
                case .cancel: completion(false)
                }
            })
        promptLog = { recorded }
        prompts = []
        return World(preferences: preferences, preview: preview, session: session,
                     controller: controller, window: window)
    }

    private nonisolated(unsafe) static var promptLog: () -> [String] = { [] }

    static func run() -> Bool {
        var passed = true
        func check(_ condition: Bool, _ label: String) {
            print("\(condition ? "  pass" : "  FAIL")  \(label)")
            passed = passed && condition
        }

        // A clean app quits immediately and is never asked anything.
        do {
            var prompts: [String] = []
            let world = makeWorld(clockAnswer: .cancel, appearanceAnswer: .cancel, prompts: &prompts)
            check(!world.controller.hasPendingDrafts, "a clean app reports no pending drafts")
            var replies: [Bool] = []
            world.controller.resolvePendingDrafts { replies.append($0) }
            check(replies == [true], "a clean app is allowed to quit with exactly one reply")
            check(promptLog().isEmpty, "a clean app is not prompted")
        }

        // Editing an existing clock, then each branch.
        for (answer, label, expectedLabel, expectedQuit) in
            [(Answer.save, "Save", "Unsaved", true),
             (Answer.discard, "Discard", "Saved", true),
             (Answer.cancel, "Cancel", "Saved", false)] {
            var prompts: [String] = []
            let world = makeWorld(clockAnswer: answer, appearanceAnswer: .discard, prompts: &prompts)
            var edited = world.preferences.clocks[0]
            edited.customLabel = "Unsaved"
            world.session.beginEditing(world.preferences.clocks[0])
            world.session.updateClock(edited)
            check(world.controller.hasPendingDrafts, "\(label): a dirty clock draft is pending")

            var replies: [Bool] = []
            world.controller.resolvePendingDrafts { replies.append($0) }
            check(replies == [expectedQuit], "\(label): exactly one reply, \(expectedQuit)")
            check(world.preferences.clocks[0].customLabel == expectedLabel,
                  "\(label): persisted label is \(world.preferences.clocks[0].customLabel ?? "nil")")
            if answer == .cancel {
                check(world.session.hasUnsavedChanges, "Cancel: the draft is still alive")
            }
        }

        // An appearance draft, each branch.
        for (answer, label, expectedSize, expectedQuit) in
            [(Answer.save, "Save", 17.0, true),
             (Answer.discard, "Discard", 13.0, true),
             (Answer.cancel, "Cancel", 13.0, false)] {
            var prompts: [String] = []
            let world = makeWorld(clockAnswer: .discard, appearanceAnswer: answer, prompts: &prompts)
            world.preview.beginAppearanceEditing()
            world.preview.appearanceDraft?.textSize = 17
            check(world.controller.hasPendingDrafts, "\(label): a dirty appearance draft is pending")
            var replies: [Bool] = []
            world.controller.resolvePendingDrafts { replies.append($0) }
            check(replies == [expectedQuit], "appearance \(label): exactly one reply, \(expectedQuit)")
            check(world.preferences.textSize == expectedSize,
                  "appearance \(label): persisted size is \(world.preferences.textSize)")
        }

        // Both dirty: the clock is asked first, then appearance.
        do {
            var prompts: [String] = []
            let world = makeWorld(clockAnswer: .save, appearanceAnswer: .save, prompts: &prompts)
            var edited = world.preferences.clocks[0]
            edited.customLabel = "Unsaved"
            world.session.beginEditing(world.preferences.clocks[0])
            world.session.updateClock(edited)
            world.preview.beginAppearanceEditing()
            world.preview.appearanceDraft?.textSize = 17
            var replies: [Bool] = []
            world.controller.resolvePendingDrafts { replies.append($0) }
            check(promptLog() == ["clock", "appearance"], "both drafts: clock is asked first")
            check(replies == [true], "both drafts: exactly one reply")
            check(world.preferences.clocks[0].customLabel == "Unsaved"
                  && world.preferences.textSize == 17, "both drafts: both were saved")
        }

        // A Save the user asked for stands even if the next prompt is cancelled.
        do {
            var prompts: [String] = []
            let world = makeWorld(clockAnswer: .save, appearanceAnswer: .cancel, prompts: &prompts)
            var edited = world.preferences.clocks[0]
            edited.customLabel = "Unsaved"
            world.session.beginEditing(world.preferences.clocks[0])
            world.session.updateClock(edited)
            world.preview.beginAppearanceEditing()
            world.preview.appearanceDraft?.textSize = 17
            var replies: [Bool] = []
            world.controller.resolvePendingDrafts { replies.append($0) }
            check(replies == [false], "cancelling the second prompt cancels the quit")
            check(world.preferences.clocks[0].customLabel == "Unsaved",
                  "the clock the user chose to save stays saved")
            check(world.preferences.textSize == 13.0, "the cancelled appearance draft is not persisted")
        }

        // An invalid draft cannot be saved, so Save must not permit the quit.
        do {
            var prompts: [String] = []
            let world = makeWorld(clockAnswer: .save, appearanceAnswer: .discard, prompts: &prompts)
            world.preview.beginAppearanceEditing()
            world.preview.appearanceDraft?.formatPreset = .custom
            world.preview.appearanceDraft?.customPattern = "HH:mm '"   // unclosed literal
            check(!world.preview.canSaveAppearance, "an unclosed literal cannot be saved")
            let saving = makeWorld(clockAnswer: .discard, appearanceAnswer: .save, prompts: &prompts)
            saving.preview.beginAppearanceEditing()
            saving.preview.appearanceDraft?.formatPreset = .custom
            saving.preview.appearanceDraft?.customPattern = "HH:mm '"
            var replies: [Bool] = []
            saving.controller.resolvePendingDrafts { replies.append($0) }
            check(replies == [false], "Save on an invalid draft does not permit the quit")
            check(saving.preview.hasAppearanceChanges, "the invalid draft is still there to fix")
        }

        // Repeated Quit while a prompt is open must not stack a second prompt.
        do {
            var prompts: [String] = []
            let world = makeWorld(clockAnswer: .cancel, appearanceAnswer: .cancel, prompts: &prompts)
            world.preview.beginAppearanceEditing()
            world.preview.appearanceDraft?.textSize = 17
            var replies: [Bool] = []
            // A confirmation that never completes stands in for an open sheet.
            world.controller.confirmations = DraftConfirmations(
                clock: { _, _, _ in }, appearance: { _, _, _ in })
            world.controller.resolvePendingDrafts { replies.append($0) }
            world.controller.resolvePendingDrafts { replies.append($0) }
            check(replies == [false], "a second Quit is refused without a second prompt")
        }
        return passed
    }
}
#endif

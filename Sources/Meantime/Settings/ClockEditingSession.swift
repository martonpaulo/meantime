import Foundation
import MeantimeKit
import Observation

/// Owns the transient add/edit flow inside the Clocks settings pane. Durable
/// preferences change only on Save; leaving an edited draft requires an
/// explicit Save or Discard decision.
@MainActor
@Observable
final class ClockEditingSession {
    enum Destination {
        case list
        case picker
        case editor
    }

    enum ExitDestination {
        case list
        case picker
    }

    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let settingsPreview: SettingsPreview

    private(set) var destination: Destination = .list
    private(set) var draft: ClockEditDraft?
    private(set) var pendingExit: ExitDestination?
    /// Prepared once per schedule change, so the editor renders from it instead
    /// of revalidating every window pair on each unrelated keystroke.
    private(set) var scheduleAnalysis: ScheduleAnalysis = .empty
    @ObservationIgnored private var analyzedWindows: [ActiveWindow] = []

    init(preferences: Preferences, settingsPreview: SettingsPreview) {
        self.preferences = preferences
        self.settingsPreview = settingsPreview
    }

    var hasUnsavedChanges: Bool { draft?.hasChanges == true }
    var canSave: Bool { draft?.canCommit == true }
    var isActive: Bool {
        switch destination {
        case .list: false
        case .picker, .editor: true
        }
    }

    func showPicker() {
        discardDraft()
        destination = .picker
    }

    func beginAdding(timeZoneID: String) {
        draft = ClockEditDraft(newTimeZoneID: timeZoneID)
        destination = .editor
        previewDraft()
        refreshScheduleAnalysis()
    }

    func beginEditing(_ clock: WorldClock) {
        draft = ClockEditDraft(existing: clock)
        destination = .editor
        previewDraft()
        refreshScheduleAnalysis()
    }

    func updateClock(_ clock: WorldClock) {
        draft?.clock = clock
        previewDraft()
        refreshScheduleAnalysis()
    }

    func restoreDefaults() {
        guard let clock = draft?.clock else { return }
        updateClock(clock.restoredToDefaults())
    }

    @discardableResult
    func save() -> Bool {
        guard draft?.commit(to: preferences) == true else { return false }
        finish(at: .list)
        return true
    }

    func requestExit(to destination: ExitDestination) {
        guard hasUnsavedChanges else {
            finish(at: destination)
            return
        }
        pendingExit = destination
    }

    func discardPendingExit() {
        guard let pendingExit else { return }
        finish(at: pendingExit)
    }

    func cancelPendingExit() {
        pendingExit = nil
    }

    /// Used by the native Settings window when the user changes panes or
    /// closes the window after confirming the external navigation.
    func discardForExternalNavigation() {
        finish(at: .list)
    }

    private func previewDraft() {
        guard let clock = draft?.clock else { return }
        settingsPreview.preview(clock: clock)
    }

    private func finish(at exit: ExitDestination) {
        discardDraft()
        switch exit {
        case .list: destination = .list
        case .picker: destination = .picker
        }
    }

    private func discardDraft() {
        draft = nil
        pendingExit = nil
        analyzedWindows = []
        scheduleAnalysis = .empty
        settingsPreview.discardClock()
    }

    /// Recomputes only when the schedule itself changed: a new label, leading
    /// item, or pinning choice leaves the prepared analysis alone.
    private func refreshScheduleAnalysis() {
        let windows = draft?.clock.activeWindows ?? []
        guard windows != analyzedWindows else { return }
        analyzedWindows = windows
        scheduleAnalysis = ScheduleAnalysis.analyze(windows)
    }
}

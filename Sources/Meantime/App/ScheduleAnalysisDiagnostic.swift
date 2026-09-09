#if DEBUG
import Foundation
import MeantimeKit

/// Debug-only check for the schedule-analysis contract (issue #21): the editing
/// session prepares validation and the Add Hours suggestion once per schedule
/// change, and an unrelated edit must not rebuild them.
///
/// Recomputation is observable without any counter: a fresh analysis carries a
/// freshly generated suggestion identifier, so an unchanged identifier proves
/// the prepared value was reused. Runs against an in-memory preference store,
/// never the owner's real defaults.
@MainActor
enum ScheduleAnalysisDiagnostic {
    static func run() -> Bool {
        let preferences = Preferences(store: EphemeralPreferenceStore())
        let session = ClockEditingSession(
            preferences: preferences, settingsPreview: SettingsPreview(preferences: preferences))

        var clock = WorldClock(timeZoneID: "UTC", customLabel: "Schedule Stress Test")
        clock.activeWindows = (0 ..< 20).map { hour in
            ActiveWindow(startMinute: hour * 60, endMinute: (hour + 1) * 60)
        }

        var passed = true
        func check(_ condition: Bool, _ label: String) {
            print("\(condition ? "  pass" : "  FAIL")  \(label)")
            passed = passed && condition
        }

        let openedAt = DispatchTime.now().uptimeNanoseconds
        session.beginEditing(clock)
        let openMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - openedAt) / 1_000_000
        print(String(format: "  info  opening the editor prepared the analysis in %.3f ms", openMilliseconds))

        let prepared = session.scheduleAnalysis
        check(prepared.issues.isEmpty, "a 20-window schedule validates clean")
        check(prepared.suggestion != nil, "Add Hours is offered for it")

        // Unrelated edits: label, leading item, pinning.
        var relabelled = clock
        relabelled.customLabel = "Renamed"
        session.updateClock(relabelled)
        check(session.scheduleAnalysis.suggestion?.id == prepared.suggestion?.id,
              "renaming the clock reuses the prepared analysis")

        var restyled = relabelled
        restyled.adornmentStyle = .none
        session.updateClock(restyled)
        check(session.scheduleAnalysis.suggestion?.id == prepared.suggestion?.id,
              "changing the leading item reuses the prepared analysis")

        var unpinned = restyled
        unpinned.isPinned = false
        session.updateClock(unpinned)
        check(session.scheduleAnalysis.suggestion?.id == prepared.suggestion?.id,
              "changing pinning reuses the prepared analysis")

        // A schedule edit must recompute.
        var rescheduled = unpinned
        rescheduled.activeWindows[0].startMinute = 5
        let changedAt = DispatchTime.now().uptimeNanoseconds
        session.updateClock(rescheduled)
        let changeMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - changedAt) / 1_000_000
        print(String(format: "  info  a schedule change recomputed the analysis in %.3f ms", changeMilliseconds))
        check(session.scheduleAnalysis.suggestion?.id != prepared.suggestion?.id,
              "changing a bound recomputes the analysis")

        // Add Hours appends exactly the prepared suggestion, then re-analyses.
        guard let offered = session.scheduleAnalysis.suggestion else {
            check(false, "Add Hours still has a suggestion after the edit")
            return passed
        }
        var extended = rescheduled
        extended.activeWindows.append(offered)
        session.updateClock(extended)
        check(session.scheduleAnalysis.issues.isEmpty, "the appended suggestion keeps the schedule valid")
        check(session.scheduleAnalysis.suggestion?.id != offered.id, "appending prepares a new suggestion")

        // Restore Defaults empties the schedule, and the analysis must follow it
        // rather than describing the schedule that was there a moment ago.
        let beforeRestore = session.scheduleAnalysis.suggestion
        session.restoreDefaults()
        check(session.scheduleAnalysis.issues.isEmpty, "Restore Defaults leaves a valid schedule")
        check(session.scheduleAnalysis.suggestion?.id != beforeRestore?.id,
              "Restore Defaults re-analyses the emptied schedule")
        check(session.scheduleAnalysis.suggestion != nil,
              "an empty schedule keeps offering its first suggestion")

        // Switching drafts must never reuse the previous draft's result.
        session.beginEditing(clock)
        let firstDraft = session.scheduleAnalysis.suggestion?.id
        session.beginEditing(WorldClock(timeZoneID: "Europe/Madrid"))
        check(session.scheduleAnalysis.issues.isEmpty
              && session.scheduleAnalysis.suggestion?.id != firstDraft,
              "an unscheduled clock prepares its own analysis, not the previous draft's")
        session.beginEditing(clock)
        check(session.scheduleAnalysis.suggestion?.id != firstDraft,
              "returning to the first clock re-analyses rather than reusing")

        // An invalid schedule reports issues and offers nothing.
        var clashing = clock
        clashing.activeWindows = [
            ActiveWindow(startMinute: 540, endMinute: 720),
            ActiveWindow(startMinute: 600, endMinute: 780),
        ]
        session.beginEditing(clashing)
        check(!session.scheduleAnalysis.issues.isEmpty, "an overlapping schedule reports issues")
        check(session.scheduleAnalysis.suggestion == nil, "an invalid schedule offers no suggestion")

        session.discardForExternalNavigation()
        check(session.scheduleAnalysis == .empty, "ending the draft clears the prepared analysis")

        return passed
    }
}
#endif

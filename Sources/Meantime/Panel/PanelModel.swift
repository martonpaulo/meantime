import Foundation
import MeantimeKit
import Observation

/// Transient panel state. The time-travel preview is a typed time and/or a day
/// picked on the calendar — deliberately not persisted; it resets every time
/// the panel opens, so the panel always opens on "now".
@MainActor
@Observable
final class PanelModel {
    /// The calendar day being previewed; nil = today.
    var selectedDay: Date?
    /// The typed clock time being previewed (local zone); nil = current time.
    var selectedTime: Date?
    /// The month the calendar is browsing; nil = the current month. Browsing
    /// alone never changes the preview — only picking a day does.
    var displayedMonth: Date?

    var isTraveling: Bool { selectedDay != nil || selectedTime != nil }

    func reset() {
        selectedDay = nil
        selectedTime = nil
        displayedMonth = nil
    }

    /// Return the calendar to today's date without discarding a typed time.
    func returnToToday() {
        selectedDay = nil
        displayedMonth = nil
    }

    /// The instant the panel is previewing, given the real current time.
    func previewDate(from now: Date) -> Date {
        guard isTraveling else { return now }
        return TimeTravel.combine(day: selectedDay ?? now, time: selectedTime ?? now)
    }
}

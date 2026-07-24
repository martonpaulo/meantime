import Foundation
import MeantimeKit
import Observation

/// Transient panel state. The time-travel preview is a typed time and/or a day
/// picked on the calendar: deliberately not persisted; it resets every time
/// the panel opens, so the panel always opens on "now".
@MainActor
@Observable
final class PanelModel {
    /// The calendar day being previewed; nil = today.
    var selectedDay: Date?
    /// The typed clock time being previewed (local zone); nil = current time.
    var selectedTime: Date?
    /// The month the calendar is browsing; nil = the current month. Browsing
    /// alone never changes the preview: only picking a day does.
    var displayedMonth: Date?

    var isTraveling: Bool { selectedDay != nil || selectedTime != nil }

    /// Whether the panel is previewing a moment that differs from now, given the
    /// real current time. A preview that lands on the current minute reads as
    /// inactive so the "Previewing…" state never shows for a no-op, and the
    /// minute-granular comparison keeps it from flickering as the seconds tick.
    func isActive(now: Date) -> Bool {
        isTraveling && !TimeTravel.sameMinute(previewDate(from: now), now)
    }

    /// Applies a typed preview time. A time that resolves to the current minute
    /// clears the selection instead of freezing a value that would drift one
    /// minute into the past at the next boundary, keeping the panel on "now".
    func setPreviewTime(_ time: Date, now: Date) {
        selectedTime = TimeTravel.sameMinute(time, now) ? nil : time
    }

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

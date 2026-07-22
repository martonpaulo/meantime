import Foundation
import MeantimeKit

/// Prepared, render-ready state for one panel row. Views stay dumb: they draw
/// this, they do not compute it.
struct PanelRow: Identifiable {
    let id: UUID
    let emoji: String
    let label: String
    let time: String
    /// Set only when the clock's calendar day differs from the local day.
    let dayCaption: String?
}

/// Turns clocks + an instant into panel rows, including the human day-difference
/// caption ("Tomorrow", "Yesterday", or a weekday) that makes world clocks
/// readable at a glance.
enum PanelRowFormatter {
    static func rows(clocks: [WorldClock], at date: Date, format: TimeFormat,
                     formatter: ClockFormatter, locale: Locale = .current) -> [PanelRow] {
        clocks.map { clock in
            PanelRow(
                id: clock.id,
                emoji: clock.displayEmoji,
                label: clock.displayLabel,
                time: formatter.string(for: date, clock: clock, format: format, locale: locale),
                dayCaption: dayCaption(for: clock.timeZone, at: date, locale: locale)
            )
        }
    }

    private static func dayCaption(for zone: TimeZone, at date: Date, locale: Locale) -> String? {
        switch CivilDay.offset(at: date, reference: .current, target: zone) {
        case 0: return nil
        case 1: return String(localized: "Tomorrow")
        case -1: return String(localized: "Yesterday")
        default:
            let weekday = DateFormatter()
            weekday.locale = locale
            weekday.timeZone = zone
            weekday.setLocalizedDateFormatFromTemplate("EEE")
            return weekday.string(from: date)
        }
    }
}

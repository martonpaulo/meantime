import Foundation
import MeantimeKit

/// Prepared, render-ready state for one panel row. Views stay dumb: they draw
/// this, they do not compute it.
struct PanelRow: Identifiable {
    let id: UUID
    let emoji: String
    let label: String
    let time: String
    /// Always present: the zone's GMT offset ("GMT−3"), DST-aware.
    let offsetCaption: String
    /// Set only when the clock's calendar day differs from the local day.
    let dayCaption: String?
}

/// Turns clocks + an instant into panel rows, including the human day-difference
/// caption ("Tomorrow", "Yesterday", or a weekday) that makes world clocks
/// readable at a glance.
enum PanelRowFormatter {
    /// Panel rows always show a complete time of day. A menu-bar format coarser
    /// than minutes (hour-only, weekday-only) falls back to the system short
    /// time here; formats that already include minutes are honored as-is.
    static func effectiveFormat(_ format: TimeFormat) -> TimeFormat {
        TimeGranularity.finest(renderMode: .timeOnly, format: format) >= .minute
            ? format
            : .system
    }

    static func rows(clocks: [WorldClock], at date: Date, format menuBarFormat: TimeFormat,
                     formatter: ClockFormatter, locale: Locale = .current) -> [PanelRow] {
        let format = effectiveFormat(menuBarFormat)
        return clocks.map { clock in
            PanelRow(
                id: clock.id,
                emoji: clock.displayEmoji,
                label: clock.displayLabel,
                time: formatter.string(for: date, clock: clock, format: format, locale: locale),
                offsetCaption: ZoneOffset.caption(for: clock.timeZone, at: date),
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

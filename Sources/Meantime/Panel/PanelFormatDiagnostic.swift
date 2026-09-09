#if DEBUG
import Foundation
import MeantimeKit

/// Debug-only check that the panel adapter renders a complete time of day for
/// every menu-bar format, and that the menu bar itself still obeys the user's
/// own pattern (issue #16). Runs on prepared state only: no window, no
/// preferences, no system settings touched.
@MainActor
enum PanelFormatDiagnostic {
    static func run() -> Bool {
        let instant = ISO8601DateFormatter().date(from: "2026-07-23T09:47:30Z")!
        let locale = Locale(identifier: "en_GB")
        let formatter = ClockFormatter()
        let clocks = [WorldClock(timeZoneID: "UTC", customLabel: "UTC")]
        let systemTime = formatter.string(for: instant, clock: clocks[0], format: .system, locale: locale)

        var passed = true
        func check(_ condition: Bool, _ label: String) {
            print("\(condition ? "  pass" : "  FAIL")  \(label)")
            passed = passed && condition
        }

        print("  info  system short time at 09:47:30 UTC, en_GB: \(systemTime)")

        for pattern in ["mm", "ss", "HH:ss", "HH", "EEE"] {
            let format = TimeFormat.custom(pattern)
            let row = PanelRowFormatter.rows(clocks: clocks, at: instant, format: format,
                                             formatter: formatter, locale: locale)[0]
            let menuBar = formatter.string(for: instant, clock: clocks[0], format: format, locale: locale)
            check(row.time == systemTime, "panel row for \"\(pattern)\" shows \(row.time)")
            check(menuBar != systemTime || pattern == "HH",
                  "the menu bar still renders \"\(pattern)\" as \(menuBar)")
        }

        for pattern in ["HH:mm", "h:mm a", "HH:mm:ss"] {
            let format = TimeFormat.custom(pattern)
            let row = PanelRowFormatter.rows(clocks: clocks, at: instant, format: format,
                                             formatter: formatter, locale: locale)[0]
            let expected = formatter.string(for: instant, clock: clocks[0], format: format, locale: locale)
            check(row.time == expected, "panel row keeps complete pattern \"\(pattern)\": \(row.time)")
        }

        let systemRow = PanelRowFormatter.rows(clocks: clocks, at: instant, format: .system,
                                               formatter: formatter, locale: locale)[0]
        check(systemRow.time == systemTime, "the system format is unchanged: \(systemRow.time)")
        check(systemRow.offsetCaption.isEmpty == false, "the row still carries its GMT caption")
        return passed
    }
}
#endif

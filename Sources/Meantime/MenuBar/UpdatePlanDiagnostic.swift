#if DEBUG
import Foundation
import MeantimeKit

/// Debug-only check that the app hands the planner the dependencies a format
/// actually has, and that closing the panel removes its finer contribution
/// (issue #15). Uses the production `MenuBarController.contribution` and the
/// production planner; no window, preferences, or system settings are touched.
@MainActor
enum UpdatePlanDiagnostic {
    static func run() -> Bool {
        let formatter = ClockFormatter()
        let newYork = TimeZone(identifier: "America/New_York")!
        let now = ISO8601DateFormatter().date(from: "2026-10-31T12:00:00Z")!

        var passed = true
        func check(_ condition: Bool, _ label: String) {
            print("\(condition ? "  pass" : "  FAIL")  \(label)")
            passed = passed && condition
        }

        func wake(_ format: TimeFormat, renderMode: ClockRenderMode = .timeOnly) -> Date? {
            let visible = MenuBarController.contribution(renderMode: renderMode, format: format,
                                                         timeZone: newYork)
            return ClockUpdatePlanner.nextUpdate(after: now, visible: [visible], formatter: formatter)
        }

        for pattern in ["a", "B", "z", "zzzz", "EEE z"] {
            guard let next = wake(.custom(pattern)) else {
                check(false, "\"\(pattern)\" got no wake at all")
                continue
            }
            let seconds = next.timeIntervalSince(now)
            check(seconds > 0 && seconds < 25 * 3_600,
                  String(format: "\"%@\" wakes in %.1f h, before the day is out", pattern, seconds / 3_600))
            check(seconds > 60, "\"\(pattern)\" is not promoted to a fast cadence")
        }

        // Panel open: the panel's effective format contributes a minute cadence
        // for a coarse menu-bar pattern. Closed, that contribution disappears.
        let menuBarOnly = MenuBarController.contribution(renderMode: .timeOnly,
                                                         format: .custom("a"), timeZone: newYork)
        let panelFormat = PanelRowFormatter.effectiveFormat(.custom("a"))
        let panelRow = MenuBarController.contribution(renderMode: .timeOnly, format: panelFormat,
                                                      timeZone: newYork)
        let open = ClockUpdatePlanner.nextUpdate(after: now, visible: [menuBarOnly, panelRow],
                                                 formatter: formatter)
        let closed = ClockUpdatePlanner.nextUpdate(after: now, visible: [menuBarOnly],
                                                   formatter: formatter)
        check(panelRow.granularity == .minute, "an open panel contributes a minute cadence")
        check(open! < closed!, "closing the panel relaxes the wake (\(open!) -> \(closed!))")
        check(closed!.timeIntervalSince(now) > 3_600, "the closed-panel wake is not per minute")

        // The search must stay a small candidate set, never a scan of the day.
        let started = DispatchTime.now().uptimeNanoseconds
        let repetitions = 200
        for _ in 0 ..< repetitions {
            _ = ClockUpdatePlanner.nextRenderedChange(after: now, format: .custom("B"),
                                                      timeZone: newYork, locale: .current,
                                                      formatter: formatter)
        }
        let each = Double(DispatchTime.now().uptimeNanoseconds - started) / Double(repetitions) / 1_000_000
        print(String(format: "  info  finding a day-period change took %.4f ms per call", each))
        check(each < 5, "the candidate search stays well under a full-second scan")
        return passed
    }
}
#endif

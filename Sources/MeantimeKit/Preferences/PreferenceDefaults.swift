import Foundation

/// Every preference fallback, in one place. Never duplicate a default in views,
/// controllers, tests, or migrations — read it from here.
public enum PreferenceDefaults {
    public static let timeFormat: TimeFormat = .system
    public static let menuBarLayout: MenuBarLayout = .individual
    public static let textSize: Double = 13
    public static let elementSpacing: Double = 4

    /// Bounds surfaced by the settings sliders.
    public static let textSizeRange: ClosedRange<Double> = 10...18
    public static let elementSpacingRange: ClosedRange<Double> = 0...12

    /// First-run seed: one pinned clock for the Mac's own zone.
    public static var clocks: [WorldClock] {
        [WorldClock(timeZoneID: TimeZone.current.identifier,
                    renderMode: .flagAndTime, isPinned: true)]
    }
}

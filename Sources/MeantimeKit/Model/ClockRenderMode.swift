import Foundation

/// How a pinned clock draws in the menu bar.
///
/// Every clock in the panel always shows flag + label + time; this choice only
/// affects a clock that has its own dedicated menu-bar item.
public enum ClockRenderMode: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Just the formatted time, e.g. `09:47`.
    case timeOnly
    /// Region flag (or the clock's custom emoji) then the time, e.g. `🇺🇸 09:47`.
    case flagAndTime
    /// A small analog clock face showing the zone's time — no text.
    case analogClock

    public var id: String { rawValue }

    /// Whether this mode draws the time as text (and so depends on the format).
    public var showsTextualTime: Bool {
        switch self {
        case .timeOnly, .flagAndTime: return true
        case .analogClock: return false
        }
    }
}

import Foundation

/// How pinned clocks occupy the menu bar.
public enum MenuBarLayout: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Each pinned clock gets its own status item.
    case individual
    /// All pinned clocks share one status item ("🇺🇸 7PM 🇧🇷 8PM").
    case combined

    public var id: String { rawValue }
}

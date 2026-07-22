import Foundation

/// The finest time field a clock's display changes on. This governs how often
/// the app updates: a clock showing only the hour must not wake every minute.
/// Ordered coarse (`day`) to fine (`second`).
public enum TimeGranularity: Int, Comparable, Sendable, CaseIterable {
    case day = 0
    case hour = 1
    case minute = 2
    case second = 3

    public static func < (lhs: TimeGranularity, rhs: TimeGranularity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The finest field a menu-bar item actually shows, given its mode + format.
    public static func finest(renderMode: ClockRenderMode, format: TimeFormat) -> TimeGranularity {
        // An analog face moves its minute hand every minute regardless of format.
        if renderMode == .analogClock { return .minute }
        switch format {
        case .system: return .minute // system short time shows minutes
        case let .custom(pattern): return from(pattern: pattern)
        }
    }

    /// The finest field a UTS-35 pattern displays.
    public static func from(pattern: String) -> TimeGranularity {
        let fields = patternFields(in: pattern)
        if fields.contains(where: { "sS".contains($0) }) { return .second }
        if fields.contains("m") { return .minute }
        if fields.contains(where: { "HhKk".contains($0) }) { return .hour }
        // Only date fields (weekday/day/month/year): changes at the day boundary.
        return .day
    }

    /// Pattern letters that lie outside single-quoted literals.
    static func patternFields(in pattern: String) -> Set<Character> {
        var fields: Set<Character> = []
        var insideLiteral = false
        for character in pattern {
            if character == "'" { insideLiteral.toggle(); continue }
            if insideLiteral { continue }
            if character.isLetter { fields.insert(character) }
        }
        return fields
    }
}

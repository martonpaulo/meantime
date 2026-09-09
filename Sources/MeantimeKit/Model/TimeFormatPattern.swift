import Foundation

/// Structure of a UTS-35 pattern: whether it is well formed, and which fields
/// it actually displays. One quote-aware owner, so cadence, hour-cycle pinning,
/// and completeness all read a pattern the same way. Field vocabulary stays
/// unrestricted so advanced patterns documented by Unicode remain available.
public enum TimeFormatPattern {
    public static func isValid(_ pattern: String) -> Bool {
        guard !pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        guard UserInputPolicy.isWithinPatternLimit(pattern) else { return false }

        var insideLiteral = false
        var index = pattern.startIndex
        while index < pattern.endIndex {
            guard pattern[index] == "'" else {
                index = pattern.index(after: index)
                continue
            }

            let next = pattern.index(after: index)
            if next < pattern.endIndex, pattern[next] == "'" {
                index = pattern.index(after: next)
            } else {
                insideLiteral.toggle()
                index = next
            }
        }
        return !insideLiteral
    }

    /// The pattern letters that lie outside single-quoted literals.
    ///
    /// A doubled apostrophe is a literal apostrophe, and toggling twice leaves
    /// the state unchanged, so `'it''s' HH` reports only the hour.
    public static func fields(in pattern: String) -> Set<Character> {
        var fields: Set<Character> = []
        var insideLiteral = false
        for character in pattern {
            if character == "'" { insideLiteral.toggle(); continue }
            if insideLiteral { continue }
            if character.isLetter { fields.insert(character) }
        }
        return fields
    }

    /// Whether the pattern displays an hour of the day, in any hour cycle.
    public static func showsHour(_ fields: Set<Character>) -> Bool {
        fields.contains { "HhKk".contains($0) }
    }

    /// Whether the pattern displays a minute.
    public static func showsMinute(_ fields: Set<Character>) -> Bool {
        fields.contains("m")
    }
}

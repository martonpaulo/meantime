import Foundation

/// Product-wide safety and legibility limits for user-authored menu-bar text.
/// Counts use extended grapheme clusters, so composed emoji and accented
/// characters are never split.
public enum UserInputPolicy {
    public static let labelLimit = 40
    public static let emojiLimit = 1
    public static let leadingTextLimit = 8
    public static let separatorLimit = 3
    public static let patternLimit = 256

    public static func isValidLabel(_ value: String?) -> Bool {
        trimmed(value).count <= labelLimit
    }

    public static func isValidEmoji(_ value: String?) -> Bool {
        trimmed(value).count == emojiLimit
    }

    public static func isValidLeadingText(_ value: String?) -> Bool {
        let text = trimmed(value)
        return !text.isEmpty && text.count <= leadingTextLimit
    }

    public static func isValidSeparator(_ value: String) -> Bool {
        value.count <= separatorLimit
    }

    public static func isWithinPatternLimit(_ value: String) -> Bool {
        value.count <= patternLimit
    }

    public static func truncated(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit))
    }

    private static func trimmed(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

public enum ClockValidationIssue: Equatable, Sendable {
    case labelTooLong
    case emojiRequired
    case emojiMustBeSingleCharacter
    case leadingTextRequired
    case leadingTextTooLong
    case invalidSchedule
}

/// One domain-owned validation path shared by Add, Edit, preview, and Save.
public enum ClockValidation {
    public static func issues(for clock: WorldClock) -> [ClockValidationIssue] {
        var result: [ClockValidationIssue] = []

        if !UserInputPolicy.isValidLabel(clock.customLabel) {
            result.append(.labelTooLong)
        }

        switch clock.adornmentStyle {
        case .emoji:
            let emoji = clock.customEmoji?.meantime_trimmed ?? ""
            if emoji.isEmpty {
                result.append(.emojiRequired)
            } else if !UserInputPolicy.isValidEmoji(emoji) {
                result.append(.emojiMustBeSingleCharacter)
            }
        case .text:
            let text = clock.customText?.meantime_trimmed ?? ""
            if text.isEmpty {
                result.append(.leadingTextRequired)
            } else if !UserInputPolicy.isValidLeadingText(text) {
                result.append(.leadingTextTooLong)
            }
        case .flag, .none:
            break
        }

        if !ScheduleValidation.issues(in: clock.activeWindows).isEmpty {
            result.append(.invalidSchedule)
        }
        return result
    }

    public static func isValid(_ clock: WorldClock) -> Bool {
        issues(for: clock).isEmpty
    }
}


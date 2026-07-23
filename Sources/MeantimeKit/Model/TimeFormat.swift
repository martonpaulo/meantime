import Foundation

/// How a clock's time is formatted.
///
/// `.system` follows the Mac's locale and 12/24-hour setting (the "reset to
/// default" target). `.custom` honors an explicit Unicode (UTS-35) pattern
/// verbatim, so power users can build any shape they want.
public enum TimeFormat: Codable, Hashable, Sendable {
    case system
    case custom(String)

    /// The explicit pattern, when the format is custom.
    public var customPattern: String? {
        if case let .custom(pattern) = self { return pattern }
        return nil
    }

    public var isSystem: Bool { self == .system }
}

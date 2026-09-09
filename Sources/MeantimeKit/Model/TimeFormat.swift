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

public extension TimeFormat {
    /// A format guaranteed to answer "what time is it".
    ///
    /// A custom pattern qualifies only when it shows both an hour and a minute.
    /// How often a pattern changes says nothing about what it displays: `ss`
    /// changes every second and `HH:ss` renders 09:30 at 09:47:30, and neither
    /// states the time. Anything short of that falls back to the system short
    /// time, the presentation a coarse menu bar already uses here. The user's
    /// stored pattern is never rewritten.
    var completeTimeOfDay: TimeFormat {
        guard case let .custom(pattern) = self else { return self }
        let fields = TimeFormatPattern.fields(in: pattern)
        return TimeFormatPattern.showsHour(fields) && TimeFormatPattern.showsMinute(fields)
            ? self
            : .system
    }
}

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

/// A named starting point offered in the format editor. The live example is
/// rendered by the shared formatter so it always reflects the user's locale.
public struct TimeFormatPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let format: TimeFormat

    public init(id: String, title: String, format: TimeFormat) {
        self.id = id
        self.title = title
        self.format = format
    }
}

public extension TimeFormat {
    /// Common formats, coarse-to-fine, ending with richer date shapes. These are
    /// starting points — the field is fully editable.
    static let presets: [TimeFormatPreset] = [
        .init(id: "system", title: "System default", format: .system),
        .init(id: "h24", title: "24-hour", format: .custom("HH:mm")),
        .init(id: "h24-lean", title: "24-hour, no leading zero", format: .custom("H:mm")),
        .init(id: "h12", title: "12-hour", format: .custom("h:mm a")),
        .init(id: "h12-lean", title: "12-hour, compact", format: .custom("h:mm")),
        .init(id: "seconds", title: "With seconds", format: .custom("HH:mm:ss")),
        .init(id: "hour-only", title: "Hour only", format: .custom("HH")),
        .init(id: "weekday", title: "Weekday + time", format: .custom("EEE HH:mm")),
        .init(id: "date", title: "Date + time", format: .custom("d MMM, HH:mm")),
    ]
}

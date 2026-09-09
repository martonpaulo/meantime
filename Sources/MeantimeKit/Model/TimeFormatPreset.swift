import Foundation

/// Common starting points for time formatting. Preferences still persist the
/// resulting `TimeFormat`, so adding or reordering presets never migrates a
/// user's saved choice.
public enum TimeFormatPreset: String, CaseIterable, Sendable, Identifiable {
    case systemDefault
    case twentyFourHour
    case twentyFourHourSeconds
    case twelveHour
    case twelveHourSeconds
    case dateAndTime
    case fullDateAndTime
    case custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .systemDefault: "System Default"
        case .twentyFourHour: "24-Hour: 09:47"
        case .twentyFourHourSeconds: "24-Hour with Seconds: 09:47:30"
        case .twelveHour: "12-Hour: 9:47 AM"
        case .twelveHourSeconds: "12-Hour with Seconds: 9:47:30 AM"
        case .dateAndTime: "Date and Time: Thu 23 Jul · 09:47"
        case .fullDateAndTime: "Full Date and Time"
        case .custom: "Custom…"
        }
    }

    public var format: TimeFormat? {
        switch self {
        case .systemDefault: .system
        case .twentyFourHour: .custom("HH:mm")
        case .twentyFourHourSeconds: .custom("HH:mm:ss")
        case .twelveHour: .custom("h:mm a")
        case .twelveHourSeconds: .custom("h:mm:ss a")
        case .dateAndTime: .custom("EEE d MMM · HH:mm")
        case .fullDateAndTime: .custom("EEEE, MMMM d, yyyy · h:mm a")
        case .custom: nil
        }
    }

    public static func matching(_ format: TimeFormat) -> TimeFormatPreset {
        allCases.first { $0.format == format } ?? .custom
    }
}

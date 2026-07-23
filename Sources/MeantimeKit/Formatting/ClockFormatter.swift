import Foundation

/// Formats an instant for a given time zone and format, reusing cached
/// `DateFormatter`s so the menu-bar update path allocates nothing.
///
/// Thread-safe: `DateFormatter.string(from:)` is safe for concurrent use once
/// the formatter is configured, and `NSCache` is itself thread-safe: hence the
/// audited `@unchecked Sendable`.
public final class ClockFormatter: @unchecked Sendable {
    private let cache = NSCache<NSString, DateFormatter>()

    public init() {}

    /// Formats `date` as seen from `clock`'s zone.
    public func string(for date: Date, clock: WorldClock, format: TimeFormat,
                       locale: Locale = .current) -> String {
        string(for: date, timeZone: clock.timeZone, format: format, locale: locale)
    }

    /// Formats `date` as seen from `timeZone`.
    public func string(for date: Date, timeZone: TimeZone, format: TimeFormat,
                       locale: Locale = .current) -> String {
        formatter(timeZone: timeZone, format: format, locale: locale).string(from: date)
    }

    private func formatter(timeZone: TimeZone, format: TimeFormat, locale: Locale) -> DateFormatter {
        let key = cacheKey(timeZone: timeZone, format: format, locale: locale) as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        switch format {
        case .system:
            // Short time honors the Mac's locale and 12/24-hour setting.
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        case let .custom(pattern):
            // Honor the user's explicit pattern verbatim. macOS rewrites explicit
            // hour fields (H ↔ h a) to match the system 12/24-hour override, so
            // pin the locale's hour cycle to what the pattern actually asks for -
            // keeping localized weekday/month names intact.
            formatter.locale = Self.pinningHourCycle(of: locale, to: pattern)
            formatter.dateFormat = pattern
        }
        cache.setObject(formatter, forKey: key)
        return formatter
    }

    /// A copy of `locale` whose hour cycle matches the pattern's hour fields,
    /// so the system 12/24-hour preference can never rewrite them.
    private static func pinningHourCycle(of locale: Locale, to pattern: String) -> Locale {
        let fields = TimeGranularity.patternFields(in: pattern)
        var components = Locale.Components(locale: locale)
        if fields.contains("H") || fields.contains("k") {
            components.hourCycle = .zeroToTwentyThree
        } else if fields.contains("h") || fields.contains("K") {
            components.hourCycle = .oneToTwelve
        }
        return Locale(components: components)
    }

    private func cacheKey(timeZone: TimeZone, format: TimeFormat, locale: Locale) -> String {
        let formatPart: String
        switch format {
        case .system: formatPart = "system"
        case let .custom(pattern): formatPart = "custom:\(pattern)"
        }
        return "\(timeZone.identifier)|\(locale.identifier)|\(formatPart)"
    }
}

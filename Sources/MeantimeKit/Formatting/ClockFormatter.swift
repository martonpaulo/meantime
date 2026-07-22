import Foundation

/// Formats an instant for a given time zone and format, reusing cached
/// `DateFormatter`s so the menu-bar update path allocates nothing.
///
/// Thread-safe: `DateFormatter.string(from:)` is safe for concurrent use once
/// the formatter is configured, and `NSCache` is itself thread-safe — hence the
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
            // Honor the user's explicit pattern verbatim. (Using a localized
            // template would reorder fields per locale, which is not wanted.)
            formatter.dateFormat = pattern
        }
        cache.setObject(formatter, forKey: key)
        return formatter
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

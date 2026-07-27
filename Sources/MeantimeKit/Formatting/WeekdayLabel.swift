import Foundation

/// Localized weekday names. The one home for turning a `Weekday` (or a set of
/// them) into text, so the day picker, its accessibility labels, and any
/// schedule summary never drift apart.
///
/// Thread-safe for the same audited reasons as `ClockFormatter`: symbol arrays
/// are read from a fully configured formatter and `NSCache` is thread-safe.
public enum WeekdayLabel {
    /// A shortest-form symbol for a compact picker: "M", "T", "S"… Ambiguous by
    /// design - the platform's own day pickers use it - so it is always paired
    /// with a full-name accessibility label.
    public static func compact(_ day: Weekday, locale: Locale = .current) -> String {
        symbols(for: locale).veryShort[day.rawValue - 1]
    }

    /// An abbreviated name for summaries: "Mon", "Tue"…
    public static func short(_ day: Weekday, locale: Locale = .current) -> String {
        symbols(for: locale).short[day.rawValue - 1]
    }

    /// The full name, used wherever the text is read aloud rather than scanned.
    public static func full(_ day: Weekday, locale: Locale = .current) -> String {
        symbols(for: locale).full[day.rawValue - 1]
    }

    /// The abbreviated names of `days` in the locale's week order, joined for a
    /// caption or an accessibility label: "Mon, Wed, Fri". Empty stays empty -
    /// a schedule row with no days is a validation error, not something to
    /// describe.
    public static func summary(_ days: Set<Weekday>, locale: Locale = .current,
                               calendar: Calendar = .current) -> String {
        Weekday.ordered(for: calendar)
            .filter(days.contains)
            .map { short($0, locale: locale) }
            .joined(separator: ", ")
    }

    // MARK: - Symbol cache

    private final class Symbols {
        let veryShort: [String]
        let short: [String]
        let full: [String]

        init(locale: Locale) {
            let formatter = DateFormatter()
            formatter.locale = locale
            // Symbol arrays are indexed by Gregorian weekday - 1, which is
            // exactly `Weekday`'s raw-value convention.
            veryShort = formatter.veryShortWeekdaySymbols ?? []
            short = formatter.shortWeekdaySymbols ?? []
            full = formatter.weekdaySymbols ?? []
        }
    }

    /// Immutable symbol sets behind a thread-safe `NSCache`, so the audited
    /// `@unchecked Sendable` holds for the same reasons it does in
    /// `ClockFormatter`.
    private final class SymbolCache: @unchecked Sendable {
        private let cache = NSCache<NSString, Symbols>()

        func symbols(for locale: Locale) -> Symbols {
            let key = locale.identifier as NSString
            if let cached = cache.object(forKey: key) { return cached }
            let symbols = Symbols(locale: locale)
            cache.setObject(symbols, forKey: key)
            return symbols
        }
    }

    private static let cache = SymbolCache()

    private static func symbols(for locale: Locale) -> Symbols {
        cache.symbols(for: locale)
    }
}

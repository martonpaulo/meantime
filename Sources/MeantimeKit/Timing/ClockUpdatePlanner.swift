import Foundation

/// Pure scheduler math. Given the clocks currently visible, it computes the next
/// instant the menu bar must refresh: the earliest boundary across all of them
///: so the app wakes exactly when a shown value changes and never more often.
public enum ClockUpdatePlanner {
    /// One visible menu-bar contribution: how fine it ticks and in which zone
    /// (the zone only matters at hour/day granularity, where offsets shift the
    /// boundary).
    public struct Visible: Sendable, Equatable {
        public var granularity: TimeGranularity
        public var timeZone: TimeZone
        /// Set when the output also changes at instants no fixed field boundary
        /// predicts: a localized day period, or a zone name that follows an
        /// offset transition. Those instants are found by rendering.
        public var rendered: RenderedOutput?

        /// What to render when the change instants have to be observed rather
        /// than derived.
        public struct RenderedOutput: Sendable, Equatable {
            public var format: TimeFormat
            public var locale: Locale

            public init(format: TimeFormat, locale: Locale) {
                self.format = format
                self.locale = locale
            }
        }

        public init(granularity: TimeGranularity, timeZone: TimeZone,
                    rendered: RenderedOutput? = nil) {
            self.granularity = granularity
            self.timeZone = timeZone
            self.rendered = rendered
        }
    }

    /// The next instant to refresh, or nil when nothing visible shows changing
    /// time and no transition is pending (in which case no timer runs at all).
    /// `transitions` are extra wake instants: e.g. a scheduled clock appearing
    /// or disappearing: that must fire even if nothing else is visible.
    public static func nextUpdate(
        after now: Date,
        visible: [Visible],
        transitions: [Date] = [],
        calendar: Calendar = Calendar(identifier: .gregorian),
        formatter: ClockFormatter = ClockFormatter()
    ) -> Date? {
        var deadlines: [Date] = []
        for item in visible {
            deadlines.append(nextBoundary(after: now, granularity: item.granularity,
                                          timeZone: item.timeZone, calendar: calendar))
            guard let rendered = item.rendered else { continue }
            if let change = nextRenderedChange(after: now, format: rendered.format,
                                               timeZone: item.timeZone, locale: rendered.locale,
                                               formatter: formatter, calendar: calendar) {
                deadlines.append(change)
            }
        }
        return (deadlines + transitions.filter { $0 > now }).min()
    }

    /// How far ahead a day period is looked for: one long local day, so a
    /// 25-hour daylight-saving day is still covered.
    private static let dayPeriodHorizonHours = 26
    /// How many offset transitions are examined before concluding the zone's
    /// displayed form never changes (a `VV` identifier never does).
    private static let zoneTransitionsExamined = 4

    /// The next instant at which the pattern's own rendered output differs from
    /// what it renders now.
    ///
    /// Localized day periods and zone names change on rules this app does not
    /// own, so the instants are found by asking the formatter rather than by
    /// reimplementing a locale table. The candidate set is small and bounded:
    /// the ends of the coming hours, plus the zone's own offset transitions.
    /// Nothing is scanned second by second.
    public static func nextRenderedChange(
        after now: Date,
        format: TimeFormat,
        timeZone: TimeZone,
        locale: Locale,
        formatter: ClockFormatter,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Date? {
        let dependencies = DisplayDependencies.of(renderMode: .timeOnly, format: format)
        guard dependencies.needsRenderedComparison else { return nil }

        var candidates: [Date] = []
        if dependencies.showsDayPeriod {
            // Hour ends, taken from the same future-safe interval helper the
            // ordinary cadence uses, so a repeated or fractional hour advances.
            var cursor = now
            for _ in 0 ..< dayPeriodHorizonHours {
                cursor = nextBoundary(after: cursor, granularity: .hour,
                                      timeZone: timeZone, calendar: calendar)
                candidates.append(cursor)
            }
        }
        if dependencies.showsZoneDisplay {
            var cursor = now
            for _ in 0 ..< zoneTransitionsExamined {
                guard let jump = timeZone.nextDaylightSavingTimeTransition(after: cursor) else { break }
                candidates.append(jump)
                cursor = jump
            }
        }

        let current = formatter.string(for: now, timeZone: timeZone, format: format, locale: locale)
        for candidate in candidates.sorted() where candidate > now {
            if formatter.string(for: candidate, timeZone: timeZone,
                                format: format, locale: locale) != current {
                return candidate
            }
        }
        return nil
    }

    /// The next instant strictly after `now` at which a value shown at
    /// `granularity` changes in `timeZone`: the end of the calendar interval
    /// that actually contains `now`.
    ///
    /// Flooring `now` into date components and adding one unit cannot express
    /// which occurrence of a repeated local hour we are in, so on a DST fall-back
    /// it reconstructs the *first* occurrence and returns a deadline in the past.
    /// Asking the calendar for the interval around the instant keeps that
    /// distinction, and handles fractional-hour offsets and short/long days.
    public static func nextBoundary(
        after now: Date,
        granularity: TimeGranularity,
        timeZone: TimeZone,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Date {
        var calendar = calendar
        calendar.timeZone = timeZone

        let unit: Calendar.Component
        switch granularity {
        case .second: unit = .second
        case .minute: unit = .minute
        case .hour: unit = .hour
        case .day: unit = .day
        }

        if let end = calendar.dateInterval(of: unit, for: now)?.end, end > now {
            return end
        }
        // The scheduler must never hand the ticker an expired deadline: an
        // exceptional calendar would otherwise make it rearm in a tight loop.
        return now.addingTimeInterval(fallbackInterval(for: granularity))
    }

    /// Nominal length of one unit, used only when the calendar cannot bound the
    /// interval containing `now`. A coarse but future deadline beats spinning.
    private static func fallbackInterval(for granularity: TimeGranularity) -> TimeInterval {
        switch granularity {
        case .second: return 1
        case .minute: return 60
        case .hour: return 3_600
        case .day: return 86_400
        }
    }
}

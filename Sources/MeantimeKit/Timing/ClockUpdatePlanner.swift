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

        public init(granularity: TimeGranularity, timeZone: TimeZone) {
            self.granularity = granularity
            self.timeZone = timeZone
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
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Date? {
        let boundaries = visible.map {
            nextBoundary(after: now, granularity: $0.granularity, timeZone: $0.timeZone, calendar: calendar)
        }
        return (boundaries + transitions.filter { $0 > now }).min()
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

import Foundation

/// Pure scheduler math. Given the clocks currently visible, it computes the next
/// instant the menu bar must refresh — the earliest boundary across all of them
/// — so the app wakes exactly when a shown value changes and never more often.
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
    /// `transitions` are extra wake instants — e.g. a scheduled clock appearing
    /// or disappearing — that must fire even if nothing else is visible.
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
    /// `granularity` changes in `timeZone`. Computed by flooring `now` to the
    /// unit in that zone and adding one unit, so DST and fractional-hour offsets
    /// are handled by `Calendar`.
    public static func nextBoundary(
        after now: Date,
        granularity: TimeGranularity,
        timeZone: TimeZone,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Date {
        var calendar = calendar
        calendar.timeZone = timeZone

        let flooringComponents: Set<Calendar.Component>
        let unit: Calendar.Component
        switch granularity {
        case .second:
            flooringComponents = [.year, .month, .day, .hour, .minute, .second]
            unit = .second
        case .minute:
            flooringComponents = [.year, .month, .day, .hour, .minute]
            unit = .minute
        case .hour:
            flooringComponents = [.year, .month, .day, .hour]
            unit = .hour
        case .day:
            flooringComponents = [.year, .month, .day]
            unit = .day
        }

        let floored = calendar.date(from: calendar.dateComponents(flooringComponents, from: now)) ?? now
        return calendar.date(byAdding: unit, value: 1, to: floored) ?? now.addingTimeInterval(1)
    }
}

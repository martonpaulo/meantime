import Foundation

/// A day of the week. Raw values match `Calendar`'s Gregorian `weekday`
/// component (1 = Sunday), so a component read maps straight to a case without
/// a second convention to keep in sync.
public enum Weekday: Int, Codable, Hashable, Sendable, CaseIterable, Comparable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Every day - the default for a schedule window, and what a window stored
    /// before per-day scheduling existed means.
    public static let everyDay: Set<Weekday> = Set(allCases)

    /// The Gregorian work week. Not locale-aware on purpose: this is the
    /// starting point a user then edits, not a claim about their week.
    public static let workweek: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    public static let weekend: Set<Weekday> = [.saturday, .sunday]

    public init?(calendarWeekday: Int) {
        self.init(rawValue: calendarWeekday)
    }

    /// The day before this one, wrapping across the week boundary.
    public var previous: Weekday {
        Weekday(rawValue: (rawValue + 5) % 7 + 1)!
    }

    /// The days in the reading order of `calendar`, so a picker starts on the
    /// user's own first weekday (Sunday in the US, Monday in most of Europe).
    public static func ordered(for calendar: Calendar) -> [Weekday] {
        let first = min(max(calendar.firstWeekday, 1), 7)
        return (0..<7).compactMap { Weekday(rawValue: (first - 1 + $0) % 7 + 1) }
    }
}

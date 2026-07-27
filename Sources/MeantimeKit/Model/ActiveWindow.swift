import Foundation

/// A recurring window during which a pinned clock appears in the menu bar: a
/// set of weekdays plus a start and end expressed in minutes from midnight
/// **in the clock's own time zone** - "NY Mon-Fri 8:00-12:00" means 8 AM to
/// noon New York time on New York weekdays, whatever that is locally.
/// An end at or before the start wraps past midnight (Fri 22:00-06:00 runs
/// into Saturday morning); the window belongs to the day it starts on.
public struct ActiveWindow: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    /// The days this window starts on. Never empty in a valid schedule.
    public var days: Set<Weekday>
    /// 0...1439, minutes from the zone's midnight.
    public var startMinute: Int
    /// 1...1440, minutes from the zone's midnight.
    public var endMinute: Int

    public init(id: UUID = UUID(), days: Set<Weekday> = Weekday.everyDay,
                startMinute: Int, endMinute: Int) {
        self.id = id
        self.days = days
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    private enum CodingKeys: String, CodingKey { case id, days, startMinute, endMinute }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startMinute = try container.decode(Int.self, forKey: .startMinute)
        endMinute = try container.decode(Int.self, forKey: .endMinute)
        // Windows stored before per-day scheduling existed ran every day.
        days = Set(try container.decodeIfPresent([Weekday].self, forKey: .days) ?? Weekday.allCases)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        // Sorted so re-encoding an unchanged schedule produces identical bytes.
        try container.encode(days.sorted(), forKey: .days)
        try container.encode(startMinute, forKey: .startMinute)
        try container.encode(endMinute, forKey: .endMinute)
    }

    /// How long the window lasts, in minutes, including the overnight wrap.
    var durationMinutes: Int {
        startMinute < endMinute ? endMinute - startMinute : 1_440 - startMinute + endMinute
    }
}

/// Pure schedule math for scheduled menu-bar visibility.
public enum ClockSchedule {
    /// Whether a clock with `windows` is visible at `date`. No windows = always.
    public static func isActive(at date: Date, windows: [ActiveWindow], timeZone: TimeZone) -> Bool {
        let windows = validWindows(windows)
        guard !windows.isEmpty else { return true }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let today = Weekday(calendarWeekday: calendar.component(.weekday, from: date)) else {
            return true
        }
        let minute = minuteOfDay(at: date, in: timeZone)
        return windows.contains { window in
            if window.startMinute < window.endMinute {
                return window.days.contains(today)
                    && minute >= window.startMinute && minute < window.endMinute
            }
            // Wraps past midnight, so the tail belongs to the previous day's window.
            if window.days.contains(today), minute >= window.startMinute { return true }
            return window.days.contains(today.previous) && minute < window.endMinute
        }
    }

    /// The next instant visibility flips (on either edge of any window), so the
    /// scheduler can wake exactly then. Nil when there is no schedule.
    public static func nextTransition(after date: Date, windows: [ActiveWindow],
                                      timeZone: TimeZone) -> Date? {
        let windows = validWindows(windows)
        guard !windows.isEmpty else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        // A window can have started yesterday and end today, and a window on a
        // single weekday can be a whole week out, so scan one week ahead plus
        // the day before.
        let startOfDay = calendar.startOfDay(for: date)
        var earliest: Date?
        for dayOffset in -1...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay),
                  let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: day))
            else { continue }
            for window in windows where window.days.contains(weekday) {
                for edge in [window.startMinute, window.startMinute + window.durationMinutes] {
                    guard let instant = instant(onDay: day, minuteOfDay: edge, calendar: calendar),
                          instant > date else { continue }
                    if earliest == nil || instant < earliest! { earliest = instant }
                }
            }
        }
        return earliest
    }

    /// A wall-clock instant on `day`, where a minute past 1439 rolls into the
    /// following day. Built from calendar components rather than by adding
    /// elapsed minutes, so a DST day still puts "17:00" at 17:00 local.
    private static func instant(onDay day: Date, minuteOfDay minute: Int,
                                calendar: Calendar) -> Date? {
        guard let base = minute >= 1_440
            ? calendar.date(byAdding: .day, value: minute / 1_440, to: day)
            : day else { return nil }
        let inDay = minute % 1_440
        var parts = calendar.dateComponents([.year, .month, .day], from: base)
        parts.hour = inDay / 60
        parts.minute = inDay % 60
        return calendar.date(from: parts)
    }

    static func minuteOfDay(at date: Date, in timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private static func validWindows(_ windows: [ActiveWindow]) -> [ActiveWindow] {
        windows.filter(ScheduleValidation.isStructurallyValid)
    }
}

public enum ScheduleValidationIssue: Equatable, Sendable {
    case outOfBounds(windowID: UUID)
    case equalBounds(windowID: UUID)
    case noDays(windowID: UUID)
    case duplicate(firstID: UUID, secondID: UUID)
    case overlap(firstID: UUID, secondID: UUID)
}

/// Edit-time validation. Runtime also filters invalid legacy bounds so a bad
/// stored row never creates false transition wakes.
public enum ScheduleValidation {
    public static func issues(in windows: [ActiveWindow]) -> [ScheduleValidationIssue] {
        var result: [ScheduleValidationIssue] = []
        for window in windows {
            guard (0..<1_440).contains(window.startMinute),
                  (0...1_440).contains(window.endMinute) else {
                result.append(.outOfBounds(windowID: window.id))
                continue
            }
            if window.startMinute == window.endMinute {
                result.append(.equalBounds(windowID: window.id))
            }
            if window.days.isEmpty {
                result.append(.noDays(windowID: window.id))
            }
        }

        for firstIndex in windows.indices {
            for secondIndex in windows.indices where secondIndex > firstIndex {
                let first = windows[firstIndex]
                let second = windows[secondIndex]
                guard isStructurallyValid(first), isStructurallyValid(second) else { continue }
                if first.startMinute == second.startMinute,
                   first.endMinute == second.endMinute,
                   first.days == second.days {
                    result.append(.duplicate(firstID: first.id, secondID: second.id))
                } else if overlaps(first, second) {
                    result.append(.overlap(firstID: first.id, secondID: second.id))
                }
            }
        }
        return result
    }

    static func isStructurallyValid(_ window: ActiveWindow) -> Bool {
        (0..<1_440).contains(window.startMinute)
            && (0...1_440).contains(window.endMinute)
            && window.startMinute != window.endMinute
            && !window.days.isEmpty
    }

    private static func overlaps(_ first: ActiveWindow, _ second: ActiveWindow) -> Bool {
        !coveredMinutes(first).isDisjoint(with: coveredMinutes(second))
    }

    /// The minutes of the week a window covers, so an overnight window that
    /// spills into a day it does not list is still compared honestly.
    private static func coveredMinutes(_ window: ActiveWindow) -> Set<Int> {
        var covered: Set<Int> = []
        let duration = window.durationMinutes
        for day in window.days {
            let start = (day.rawValue - 1) * 1_440 + window.startMinute
            for offset in 0..<duration { covered.insert((start + offset) % 10_080) }
        }
        return covered
    }
}

/// Produces an add-row default only when it can be inserted without creating
/// an invalid, duplicate, or overlapping schedule.
public enum ScheduleSuggestion {
    public static func nextWindow(existing: [ActiveWindow]) -> ActiveWindow? {
        let claimed = existing.reduce(into: Set<Weekday>()) { $0.formUnion($1.days) }
        let free = Weekday.everyDay.subtracting(claimed)

        // Splitting a schedule by day is the common second window ("weekdays
        // like this, weekends like that"), so first offer the untouched days at
        // hours the user already chose.
        if let hours = existing.first, !free.isEmpty {
            let candidate = ActiveWindow(days: free, startMinute: hours.startMinute,
                                         endMinute: hours.endMinute)
            if ScheduleValidation.issues(in: existing + [candidate]).isEmpty { return candidate }
        }

        for days in free.isEmpty ? [Weekday.everyDay] : [free, Weekday.everyDay] {
            for duration in [4 * 60, 2 * 60, 60] {
                for start in stride(from: 0, to: 1_440, by: 60) {
                    let candidate = ActiveWindow(days: days, startMinute: start,
                                                 endMinute: (start + duration) % 1_440)
                    if ScheduleValidation.issues(in: existing + [candidate]).isEmpty {
                        return candidate
                    }
                }
            }
        }
        return nil
    }
}

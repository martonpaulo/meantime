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
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return isActive(at: date, windows: validWindows(windows), calendar: calendar)
    }

    /// The same rule with the calendar already prepared and the windows already
    /// filtered, so transition discovery can evaluate hundreds of candidates
    /// without rebuilding a `Calendar` for each one.
    static func isActive(at date: Date, windows: [ActiveWindow], calendar: Calendar) -> Bool {
        guard !windows.isEmpty else { return true }
        guard let today = Weekday(calendarWeekday: calendar.component(.weekday, from: date)) else {
            return true
        }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
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

        // An offset jump can flip visibility with no nominal edge at all: a
        // window starting inside a skipped hour begins at the jump itself. The
        // API is named for daylight saving but Foundation reports plain
        // political offset changes through it too.
        let horizonStart = calendar.date(byAdding: .day, value: -2, to: startOfDay) ?? startOfDay
        let horizonEnd = date.addingTimeInterval(9 * 86_400)
        var candidates: Set<Date> = []
        var jumps: [Date] = []
        var cursor = horizonStart
        while let jump = timeZone.nextDaylightSavingTimeTransition(after: cursor), jump <= horizonEnd {
            jumps.append(jump)
            if jump > date { candidates.insert(jump) }
            cursor = jump
        }

        // Civil days are prepared once: `startOfDay` and day arithmetic are far
        // too dear to repeat for every edge of every window.
        let offsets = Array(-1...9)
        let days = offsets.map { calendar.date(byAdding: .day, value: $0, to: startOfDay) }
        let dayHasJump = days.indices.map { index -> Bool in
            guard let start = days[index],
                  let end = index + 1 < days.count ? days[index + 1] : nil else { return true }
            return jumps.contains { $0 > start && $0 < end }
        }

        for index in offsets.indices where offsets[index] <= 8 {
            guard let day = days[index],
                  let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: day))
            else { continue }
            for window in windows where window.days.contains(weekday) {
                for edge in [window.startMinute, window.startMinute + window.durationMinutes] {
                    // An edge past midnight belongs to the following civil day.
                    let dayIndex = index + edge / 1_440
                    guard dayIndex < days.count, let base = days[dayIndex] else { continue }
                    collectRealizations(ofMinute: edge % 1_440, onDay: base, calendar: calendar,
                                        dayHasJump: dayHasJump[dayIndex], after: date,
                                        into: &candidates)
                }
            }
        }

        // Visibility can only change at one of these instants, so it is constant
        // between them: the first candidate whose state differs from the state
        // now is the transition. Letting `isActive` decide keeps the two in
        // step, so a repeated local time is offered twice, a skipped one never,
        // and an edge hidden under another window is not reported as a change.
        let current = isActive(at: date, windows: windows, calendar: calendar)
        for candidate in candidates.sorted() {
            if isActive(at: candidate, windows: windows, calendar: calendar) != current {
                return candidate
            }
        }
        return nil
    }

    /// Adds every instant on `base` at which the local clock actually reads
    /// `inDay` minutes past midnight.
    ///
    /// A repeated local hour yields two instants and a skipped one yields none,
    /// which is exactly what `isActive` sees. Matching is strict on purpose: a
    /// nonexistent 02:30 must not be normalized into 03:30 and reported as a
    /// wake that the wall clock never reaches.
    private static func collectRealizations(ofMinute inDay: Int, onDay base: Date,
                                            calendar: Calendar, dayHasJump: Bool, after date: Date,
                                            into candidates: inout Set<Date>) {
        // On a day with no offset change every wall time exists exactly once, so
        // build it from components. The strict calendar search below is an order
        // of magnitude dearer, and almost every day is an ordinary day.
        if !dayHasJump {
            var parts = calendar.dateComponents([.year, .month, .day], from: base)
            parts.hour = inDay / 60
            parts.minute = inDay % 60
            if let instant = calendar.date(from: parts), instant > date { candidates.insert(instant) }
            return
        }

        var match = DateComponents()
        match.hour = inDay / 60
        match.minute = inDay % 60
        match.second = 0

        let searchFrom = calendar.startOfDay(for: base).addingTimeInterval(-1)
        for policy: Calendar.RepeatedTimePolicy in [.first, .last] {
            guard let instant = calendar.nextDate(after: searchFrom, matching: match,
                                                  matchingPolicy: .strict,
                                                  repeatedTimePolicy: policy,
                                                  direction: .forward),
                  calendar.isDate(instant, inSameDayAs: base), instant > date else { continue }
            candidates.insert(instant)
        }
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

        // Each window's weekly coverage is built once. Rebuilding it inside the
        // pairwise loop made validation quadratic in windows and linear in their
        // duration on top of that: a 20-window schedule spent about 10 ms here.
        let coverage = windows.map { isStructurallyValid($0) ? coveredMinutes($0) : nil }

        for firstIndex in windows.indices {
            for secondIndex in windows.indices where secondIndex > firstIndex {
                let first = windows[firstIndex]
                let second = windows[secondIndex]
                guard let firstCover = coverage[firstIndex],
                      let secondCover = coverage[secondIndex] else { continue }
                if first.startMinute == second.startMinute,
                   first.endMinute == second.endMinute,
                   first.days == second.days {
                    result.append(.duplicate(firstID: first.id, secondID: second.id))
                } else if !firstCover.isDisjoint(with: secondCover) {
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

    /// The minutes of the week a window covers, so an overnight window that
    /// spills into a day it does not list is still compared honestly.
    /// Shared with `ScheduleSuggestion` so both read occupancy the same way.
    static func coveredMinutes(_ window: ActiveWindow) -> Set<Int> {
        var covered: Set<Int> = []
        let duration = window.durationMinutes
        for day in window.days {
            let start = (day.rawValue - 1) * 1_440 + window.startMinute
            for offset in 0..<duration { covered.insert((start + offset) % 10_080) }
        }
        return covered
    }
}

/// Everything the schedule editor derives from a set of windows, produced in
/// one pass. Preparing it once per schedule change keeps the analysis out of
/// view rendering, where an unrelated label edit used to rebuild it.
public struct ScheduleAnalysis: Equatable, Sendable {
    public let issues: [ScheduleValidationIssue]
    /// The window Add Hours would append, or nil when nothing fits.
    public let suggestion: ActiveWindow?

    public static let empty = ScheduleAnalysis(issues: [], suggestion: nil)

    public static func analyze(_ windows: [ActiveWindow]) -> ScheduleAnalysis {
        let issues = ScheduleValidation.issues(in: windows)
        return ScheduleAnalysis(
            issues: issues,
            // An invalid schedule can never accept another window, and the
            // suggestion would only revalidate what was just validated.
            suggestion: issues.isEmpty ? ScheduleSuggestion.nextWindow(existing: windows) : nil)
    }
}

/// Produces an add-row default only when it can be inserted without creating
/// an invalid, duplicate, or overlapping schedule.
public enum ScheduleSuggestion {
    public static func nextWindow(existing: [ActiveWindow]) -> ActiveWindow? {
        // A schedule that is already invalid stays invalid whatever is appended,
        // so reject it once instead of revalidating it for every candidate. The
        // occupied minutes are likewise built once and reused: rebuilding them
        // per candidate cost about 245 ms for a 20-window schedule.
        guard ScheduleValidation.issues(in: existing).isEmpty else { return nil }
        var occupied: Set<Int> = []
        for window in existing { occupied.formUnion(ScheduleValidation.coveredMinutes(window)) }

        func fits(_ candidate: ActiveWindow) -> Bool {
            ScheduleValidation.isStructurallyValid(candidate)
                && ScheduleValidation.coveredMinutes(candidate).isDisjoint(with: occupied)
        }

        let claimed = existing.reduce(into: Set<Weekday>()) { $0.formUnion($1.days) }
        let free = Weekday.everyDay.subtracting(claimed)

        // Splitting a schedule by day is the common second window ("weekdays
        // like this, weekends like that"), so first offer the untouched days at
        // hours the user already chose.
        if let hours = existing.first, !free.isEmpty {
            let candidate = ActiveWindow(days: free, startMinute: hours.startMinute,
                                         endMinute: hours.endMinute)
            if fits(candidate) { return candidate }
        }

        for days in free.isEmpty ? [Weekday.everyDay] : [free, Weekday.everyDay] {
            for duration in [4 * 60, 2 * 60, 60] {
                for start in stride(from: 0, to: 1_440, by: 60) {
                    let candidate = ActiveWindow(days: days, startMinute: start,
                                                 endMinute: (start + duration) % 1_440)
                    if fits(candidate) { return candidate }
                }
            }
        }
        return nil
    }
}

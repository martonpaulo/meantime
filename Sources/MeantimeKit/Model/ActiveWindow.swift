import Foundation

/// A daily window during which a pinned clock appears in the menu bar,
/// expressed in minutes from midnight **in the clock's own time zone** -
/// "NY 8:00–12:00" means 8 AM to noon New York time, whatever that is locally.
/// An end at or before the start wraps past midnight (22:00–06:00).
public struct ActiveWindow: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    /// 0...1439, minutes from the zone's midnight.
    public var startMinute: Int
    /// 1...1440, minutes from the zone's midnight.
    public var endMinute: Int

    public init(id: UUID = UUID(), startMinute: Int, endMinute: Int) {
        self.id = id
        self.startMinute = startMinute
        self.endMinute = endMinute
    }
}

/// Pure schedule math for scheduled menu-bar visibility.
public enum ClockSchedule {
    /// Whether a clock with `windows` is visible at `date`. No windows = always.
    public static func isActive(at date: Date, windows: [ActiveWindow], timeZone: TimeZone) -> Bool {
        let windows = validWindows(windows)
        guard !windows.isEmpty else { return true }
        let minute = minuteOfDay(at: date, in: timeZone)
        return windows.contains { contains($0, minute: minute) }
    }

    /// The next instant visibility flips (on either edge of any window), so the
    /// scheduler can wake exactly then. Nil when there is no schedule.
    public static func nextTransition(after date: Date, windows: [ActiveWindow],
                                      timeZone: TimeZone) -> Date? {
        let windows = validWindows(windows)
        guard !windows.isEmpty else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        // Candidate edges today and tomorrow (a window can wrap midnight, and
        // the next edge may be tomorrow's start).
        let startOfDay = calendar.startOfDay(for: date)
        var candidates: [Date] = []
        for dayOffset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay) else { continue }
            for window in windows {
                for edge in [window.startMinute, window.endMinute] {
                    if let instant = calendar.date(byAdding: .minute, value: edge, to: day),
                       instant > date {
                        candidates.append(instant)
                    }
                }
            }
        }
        return candidates.min()
    }

    static func minuteOfDay(at date: Date, in timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private static func contains(_ window: ActiveWindow, minute: Int) -> Bool {
        if window.startMinute < window.endMinute {
            return minute >= window.startMinute && minute < window.endMinute
        }
        // Wraps midnight: active outside the gap.
        return minute >= window.startMinute || minute < window.endMinute
    }

    private static func validWindows(_ windows: [ActiveWindow]) -> [ActiveWindow] {
        windows.filter {
            (0..<1_440).contains($0.startMinute)
                && (0...1_440).contains($0.endMinute)
                && $0.startMinute != $0.endMinute
        }
    }
}

public enum ScheduleValidationIssue: Equatable, Sendable {
    case outOfBounds(windowID: UUID)
    case equalBounds(windowID: UUID)
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
        }

        for firstIndex in windows.indices {
            for secondIndex in windows.indices where secondIndex > firstIndex {
                let first = windows[firstIndex]
                let second = windows[secondIndex]
                guard isStructurallyValid(first), isStructurallyValid(second) else { continue }
                if first.startMinute == second.startMinute,
                   first.endMinute == second.endMinute {
                    result.append(.duplicate(firstID: first.id, secondID: second.id))
                } else if overlaps(first, second) {
                    result.append(.overlap(firstID: first.id, secondID: second.id))
                }
            }
        }
        return result
    }

    private static func isStructurallyValid(_ window: ActiveWindow) -> Bool {
        (0..<1_440).contains(window.startMinute)
            && (0...1_440).contains(window.endMinute)
            && window.startMinute != window.endMinute
    }

    private static func overlaps(_ first: ActiveWindow, _ second: ActiveWindow) -> Bool {
        !coveredMinutes(first).isDisjoint(with: coveredMinutes(second))
    }

    private static func coveredMinutes(_ window: ActiveWindow) -> Set<Int> {
        if window.startMinute < window.endMinute {
            return Set(window.startMinute..<window.endMinute)
        }
        return Set(window.startMinute..<1_440).union(0..<window.endMinute)
    }
}

/// Produces an add-row default only when it can be inserted without creating
/// an invalid, duplicate, or overlapping schedule.
public enum ScheduleSuggestion {
    public static func nextWindow(existing: [ActiveWindow]) -> ActiveWindow? {
        for duration in [4 * 60, 2 * 60, 60] {
            for start in stride(from: 0, to: 1_440, by: 60) {
                let end = (start + duration) % 1_440
                let candidate = ActiveWindow(startMinute: start, endMinute: end)
                if ScheduleValidation.issues(in: existing + [candidate]).isEmpty {
                    return candidate
                }
            }
        }
        return nil
    }
}

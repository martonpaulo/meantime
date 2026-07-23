import Foundation

/// A daily window during which a pinned clock appears in the menu bar,
/// expressed in minutes from midnight **in the clock's own time zone** —
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
        guard !windows.isEmpty else { return true }
        let minute = minuteOfDay(at: date, in: timeZone)
        return windows.contains { contains($0, minute: minute) }
    }

    /// The next instant visibility flips (on either edge of any window), so the
    /// scheduler can wake exactly then. Nil when there is no schedule.
    public static func nextTransition(after date: Date, windows: [ActiveWindow],
                                      timeZone: TimeZone) -> Date? {
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
}

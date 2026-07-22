import Foundation

/// Civil-calendar-day math across time zones. Used to tell the user, at a
/// glance, when a clock is on a different day than they are.
public enum CivilDay {
    /// The signed day difference at `date` between two zones (`target` minus
    /// `reference`). `+1` means the target zone's civil day is one ahead;
    /// `-1` one behind; `0` the same day.
    public static func offset(at date: Date, reference: TimeZone, target: TimeZone) -> Int {
        guard let referenceDay = civilMidnightInUTC(of: date, zone: reference),
              let targetDay = civilMidnightInUTC(of: date, zone: target) else { return 0 }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        return utc.dateComponents([.day], from: referenceDay, to: targetDay).day ?? 0
    }

    /// The civil date of `date` as seen in `zone`, re-anchored to UTC midnight so
    /// two zones' days can be compared as plain calendar days.
    private static func civilMidnightInUTC(of date: Date, zone: TimeZone) -> Date? {
        var zoned = Calendar(identifier: .gregorian)
        zoned.timeZone = zone
        let parts = zoned.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        return utc.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day))
    }
}

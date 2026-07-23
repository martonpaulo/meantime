import Foundation

/// Pure math for the panel's time-travel preview: combine a calendar day with a
/// typed clock time, both interpreted in the local zone.
public enum TimeTravel {
    /// The instant on `day` at `time`'s hour/minute (local zone by default).
    public static func combine(day: Date, time: Date, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let dayParts = calendar.dateComponents([.year, .month, .day], from: day)
        let timeParts = calendar.dateComponents([.hour, .minute], from: time)
        var combined = DateComponents()
        combined.year = dayParts.year
        combined.month = dayParts.month
        combined.day = dayParts.day
        combined.hour = timeParts.hour
        combined.minute = timeParts.minute
        return calendar.date(from: combined) ?? day
    }
}

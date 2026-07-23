import SwiftUI
import MeantimeKit

extension Binding where Value == String? {
    /// Bridges an optional-string model to a `TextField`: empty text stores nil,
    /// so a cleared field falls back to the derived default.
    func orEmpty() -> Binding<String> {
        Binding<String>(
            get: { wrappedValue ?? "" },
            set: { wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

/// Renders a small live example of a time format for the settings previews so
/// every choice shows exactly what it will look like.
enum FormatSample {
    static func example(_ format: TimeFormat, formatter: ClockFormatter,
                        now: Date = Date(), zone: TimeZone = .current) -> String {
        formatter.string(for: now, timeZone: zone, format: format)
    }
}

/// Maps an `ActiveWindow`'s minute-of-day to an editable `Date` and back, using
/// a fixed UTC reference day so DST can never skew the mapping. The date's
/// calendar day is meaningless; only hour/minute carry information.
enum ScheduleTime {
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static var referenceDay: Date {
        utcCalendar.date(from: DateComponents(year: 2001, month: 1, day: 1))!
    }

    static func date(fromMinute minute: Int) -> Date {
        referenceDay.addingTimeInterval(TimeInterval(minute * 60))
    }

    static func minute(from date: Date) -> Int {
        let parts = utcCalendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}

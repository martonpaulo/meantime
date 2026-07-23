import SwiftUI
import MeantimeKit

/// Maps an `ActiveWindow`'s minute-of-day to an editable `Date` and back, using
/// a fixed UTC reference day so DST can never skew the mapping. The date's
/// calendar day is meaningless; only hour/minute carry information.
@MainActor
enum ScheduleTime {
    /// The fixed zone the schedule fields display and edit in. A minute-of-day is
    /// zone-agnostic, so editing it here (and at runtime, in the clock's own zone)
    /// must both use one stable calendar; otherwise a local GMT offset shifts what
    /// the user types away from what is stored.
    static let zone = TimeZone(identifier: "UTC")!

    private static let labelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

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

    static func label(fromMinute minute: Int) -> String {
        labelFormatter.string(from: date(fromMinute: minute))
    }
}

/// Shared "changes are pending a Save" indicator. One definition, reused by every
/// Save-gated action bar (Format and the clock editor) so the cue reads the same
/// everywhere and stands out against the surrounding secondary text.
struct UnsavedBadge: View {
    var body: some View {
        Label("Unsaved changes", systemImage: "exclamationmark.circle.fill")
            .font(.callout)
            .foregroundStyle(Token.Color.attention)
            .accessibilityLabel("Unsaved changes")
    }
}

import Foundation

/// Pure month-grid math for the panel calendar: the weeks visible for a month,
/// honoring the calendar's first-weekday setting. Views only draw this.
public struct MonthGrid: Equatable, Sendable {
    public struct Day: Equatable, Sendable, Identifiable {
        /// Midnight of the day in the grid's calendar.
        public let date: Date
        public let dayNumber: Int
        /// False for the leading/trailing days of adjacent months.
        public let isInMonth: Bool
        /// Locale-aware weekend state prepared by `Calendar`.
        public let isWeekend: Bool

        public var id: Date { date }
    }

    public let monthStart: Date
    /// Always six whole weeks of exactly seven days. Stable geometry keeps the
    /// menu-bar panel from resizing when the visible month changes.
    public let weeks: [[Day]]

    /// The grid containing `date`'s month.
    public static func make(containing date: Date,
                            calendar: Calendar = .current) -> MonthGrid {
        // The month containing the instant, not one rebuilt from its year and
        // month numbers: those two fields do not identify a month on their own.
        // A Japanese-calendar year repeats in every era, and a leap month shares
        // its number with the regular month, so reconstruction jumped decades.
        let monthInterval = calendar.dateInterval(of: .month, for: date)
        let monthStart = monthInterval?.start ?? date

        // Back up to the first day of the week containing the 1st.
        let weekdayOfFirst = calendar.component(.weekday, from: monthStart)
        let lead = (weekdayOfFirst - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -lead, to: monthStart) else {
            return MonthGrid(monthStart: monthStart, weeks: [])
        }

        let weekCount = 6

        var weeks: [[Day]] = []
        for week in 0..<weekCount {
            var days: [Day] = []
            for slot in 0..<7 {
                guard let dayDate = calendar.date(byAdding: .day, value: week * 7 + slot, to: gridStart)
                else { continue }
                days.append(Day(
                    date: dayDate,
                    dayNumber: calendar.component(.day, from: dayDate),
                    // Membership is tested against the actual interval, so a leap
                    // month never absorbs the days of the regular month it shares
                    // a number with.
                    // DateInterval.contains is closed at both ends, and a month's
                    // end is the next month's first midnight, so compare half-open.
                    isInMonth: monthInterval.map { dayDate >= $0.start && dayDate < $0.end }
                        ?? calendar.isDate(dayDate, equalTo: monthStart, toGranularity: .month),
                    isWeekend: calendar.isDateInWeekend(dayDate)))
            }
            weeks.append(days)
        }
        return MonthGrid(monthStart: monthStart, weeks: weeks)
    }

    /// Localized single-letter weekday headers, ordered by the calendar's
    /// first weekday.
    public static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }
}

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
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: date)) ?? date

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
                    isInMonth: calendar.isDate(dayDate, equalTo: monthStart, toGranularity: .month),
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

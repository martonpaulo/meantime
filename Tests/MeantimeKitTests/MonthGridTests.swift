import Foundation
import Testing
@testable import MeantimeKit

@Suite struct MonthGridTests {
    /// A Sunday-first gregorian calendar in a fixed zone for determinism.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func julyTwentyTwentySixLaysOutCorrectly() {
        // July 1, 2026 is a Wednesday: 3 leading June days. The grid reserves
        // six rows so switching months never changes panel height.
        let grid = MonthGrid.make(containing: day(2026, 7, 23), calendar: calendar)
        #expect(grid.weeks.count == 6)
        #expect(grid.weeks.allSatisfy { $0.count == 7 })

        let firstRow = grid.weeks[0]
        #expect(firstRow[0].dayNumber == 28) // June 28
        #expect(!firstRow[0].isInMonth)
        #expect(firstRow[3].dayNumber == 1)  // July 1 under Wednesday
        #expect(firstRow[3].isInMonth)

        let fifthRow = grid.weeks[4]
        #expect(fifthRow[5].dayNumber == 31)  // July 31 on Friday
        #expect(fifthRow[6].dayNumber == 1)   // August 1 trailing
        #expect(!fifthRow[6].isInMonth)
        #expect(grid.weeks[5][0].dayNumber == 2)
        #expect(!grid.weeks[5][0].isInMonth)
    }

    @Test func mondayFirstShiftsTheLead() {
        var monday = calendar
        monday.firstWeekday = 2
        let grid = MonthGrid.make(containing: day(2026, 7, 1), calendar: monday)
        // Monday-first: July 1 (Wed) has 2 leading days (Mon 29, Tue 30).
        #expect(grid.weeks[0][0].dayNumber == 29)
        #expect(grid.weeks[0][2].dayNumber == 1)
    }

    @Test func weekdaySymbolsRotateWithFirstWeekday() {
        var monday = calendar
        monday.firstWeekday = 2
        let sundayFirst = MonthGrid.weekdaySymbols(calendar: calendar)
        let mondayFirst = MonthGrid.weekdaySymbols(calendar: monday)
        #expect(sundayFirst.count == 7)
        #expect(mondayFirst.first == sundayFirst[1])
        #expect(mondayFirst.last == sundayFirst.first)
    }

    @Test func weekendMetadataFollowsTheCalendar() {
        let grid = MonthGrid.make(containing: day(2026, 7, 1), calendar: calendar)
        #expect(grid.weeks.allSatisfy { week in
            week[0].isWeekend && week[6].isWeekend
                && week.dropFirst().dropLast().allSatisfy { !$0.isWeekend }
        })
    }

    @Test func monthFollowsTheProvidedCalendarTimeZone() {
        var kiritimati = calendar
        kiritimati.timeZone = TimeZone(identifier: "Pacific/Kiritimati")!
        let instant = calendar.date(
            from: DateComponents(year: 2026, month: 12, day: 31, hour: 11, minute: 30))!

        let grid = MonthGrid.make(containing: instant, calendar: kiritimati)
        let components = kiritimati.dateComponents(
            [.year, .month, .day],
            from: grid.monthStart)

        #expect(components.year == 2027)
        #expect(components.month == 1)
        #expect(components.day == 1)
        #expect(grid.weeks.flatMap(\.self).first(where: \.isInMonth)?.dayNumber == 1)
    }
}

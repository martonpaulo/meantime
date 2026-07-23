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
        // July 1, 2026 is a Wednesday: 3 leading June days, 5 rows total.
        let grid = MonthGrid.make(containing: day(2026, 7, 23), calendar: calendar)
        #expect(grid.weeks.count == 5)
        #expect(grid.weeks.allSatisfy { $0.count == 7 })

        let firstRow = grid.weeks[0]
        #expect(firstRow[0].dayNumber == 28) // June 28
        #expect(!firstRow[0].isInMonth)
        #expect(firstRow[3].dayNumber == 1)  // July 1 under Wednesday
        #expect(firstRow[3].isInMonth)

        let lastRow = grid.weeks[4]
        #expect(lastRow[5].dayNumber == 31)  // July 31 on Friday
        #expect(lastRow[6].dayNumber == 1)   // August 1 trailing
        #expect(!lastRow[6].isInMonth)
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
}

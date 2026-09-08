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

/// A month is identified by more than its year and month numbers: eras and leap
/// months share those numbers with other months. Rebuilding the month start from
/// components alone silently jumped decades. See issue #17.
@Suite struct MonthGridCalendarIdentityTests {
    private static func utc(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC")!
        return gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private static func calendar(_ identifier: Calendar.Identifier) -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.firstWeekday = 1
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// The grid's own month start, expressed as a Gregorian instant.
    private static func start(_ date: Date, _ identifier: Calendar.Identifier) -> Date {
        MonthGrid.make(containing: date, calendar: calendar(identifier)).monthStart
    }

    @Test func japaneseErasResolveToTheirOwnMonth() {
        // Heisei ended on 2019-04-30 and Reiwa began on 2019-05-01, so April and
        // May 2019 sit on either side of an era boundary.
        #expect(Self.start(Self.utc(2019, 4, 8), .japanese) == Self.utc(2019, 4, 1).addingTimeInterval(-43_200))
        #expect(Self.start(Self.utc(2019, 5, 8), .japanese) == Self.utc(2019, 5, 1).addingTimeInterval(-43_200))
        #expect(Self.start(Self.utc(2018, 9, 8), .japanese) == Self.utc(2018, 9, 1).addingTimeInterval(-43_200))
        #expect(Self.start(Self.utc(1988, 9, 8), .japanese) == Self.utc(1988, 9, 1).addingTimeInterval(-43_200))
    }

    @Test func gregorianAndCurrentEraBehaviorIsUnchanged() {
        #expect(Self.start(Self.utc(2026, 7, 23), .gregorian) == Self.utc(2026, 7, 1).addingTimeInterval(-43_200))
        #expect(Self.start(Self.utc(2026, 7, 23), .japanese) == Self.utc(2026, 7, 1).addingTimeInterval(-43_200))
    }

    /// The Chinese calendar repeats a month number in a leap year: 2023 has a
    /// second second-month. Both must produce their own grid, not one shared one.
    @Test func leapMonthsKeepTheirOwnGrid() {
        let regular = Self.utc(2023, 3, 1)      // second month of 2023
        let leap = Self.utc(2023, 3, 25)        // leap second month of 2023
        let regularStart = Self.start(regular, .chinese)
        let leapStart = Self.start(leap, .chinese)
        #expect(regularStart != leapStart)
        #expect(regularStart < leapStart)
        // Each start must be the month that actually contains its own input.
        var chinese = Self.calendar(.chinese)
        chinese.timeZone = TimeZone(identifier: "UTC")!
        for (input, monthStart) in [(regular, regularStart), (leap, leapStart)] {
            let interval = chinese.dateInterval(of: .month, for: input)
            #expect(interval?.start == monthStart)
            #expect(interval?.contains(input) == true)
        }
    }

    @Test func hebrewLeapYearMonthsResolveToTheirOwnStart() {
        // 5784 (2024) is a Hebrew leap year with both Adar I and Adar II.
        let adarI = Self.utc(2024, 2, 20)
        let adarII = Self.utc(2024, 3, 20)
        #expect(Self.start(adarI, .hebrew) != Self.start(adarII, .hebrew))
        let hebrew = Self.calendar(.hebrew)
        #expect(hebrew.dateInterval(of: .month, for: adarI)?.start == Self.start(adarI, .hebrew))
        #expect(hebrew.dateInterval(of: .month, for: adarII)?.start == Self.start(adarII, .hebrew))
    }

    @Test func historicalGridsKeepSixSevenDayRowsAndInMonthDays() {
        let grid = MonthGrid.make(containing: Self.utc(2018, 9, 8), calendar: Self.calendar(.japanese))
        #expect(grid.weeks.count == 6)
        #expect(grid.weeks.allSatisfy { $0.count == 7 })
        let days = grid.weeks.flatMap { $0 }
        #expect(days.count == 42)
        #expect(Set(days.map(\.date)).count == 42)
        // Sequential, one day apart, in order.
        for (earlier, later) in zip(days, days.dropFirst()) {
            #expect(later.date > earlier.date)
        }
        let inMonth = days.filter(\.isInMonth)
        #expect(inMonth.count == 30) // September has 30 days
        #expect(inMonth.first?.date == grid.monthStart)
    }

    /// A day picked from a historical grid must stay historical once time travel
    /// combines it with a typed time: the panel consumes `Day.date` directly.
    @Test func selectedHistoricalDayStaysHistoricalThroughTimeTravel() {
        var japanese = Self.calendar(.japanese)
        japanese.timeZone = TimeZone(identifier: "UTC")!
        // Reproduce the panel's Previous-year then Previous-month navigation.
        let fromNow = Self.utc(2019, 5, 8)
        let backOneYear = japanese.date(byAdding: .year, value: -1, to: fromNow)!
        let target = japanese.date(byAdding: .month, value: -1, to: backOneYear)!
        let grid = MonthGrid.make(containing: target, calendar: japanese)
        let selected = grid.weeks.flatMap { $0 }.first { $0.isInMonth && $0.dayNumber == 15 }!

        let travelled = TimeTravel.combine(day: selected.date,
                                           time: Self.utc(2026, 1, 1),
                                           timeZone: japanese.timeZone)
        #expect(travelled < Self.utc(2019, 1, 1))
        #expect(travelled > Self.utc(2018, 1, 1))
    }
}

import Foundation
import Testing
@testable import MeantimeKit

private func utc(_ year: Int, _ month: Int, _ day: Int,
                 _ hour: Int, _ minute: Int, _ second: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
}

@Suite struct TimeGranularityTests {
    @Test func finestFieldFromPattern() {
        #expect(TimeGranularity.from(pattern: "HH:mm:ss") == .second)
        #expect(TimeGranularity.from(pattern: "HH:mm") == .minute)
        #expect(TimeGranularity.from(pattern: "H:mm") == .minute)
        #expect(TimeGranularity.from(pattern: "HH") == .hour)
        #expect(TimeGranularity.from(pattern: "h a") == .hour)
        #expect(TimeGranularity.from(pattern: "EEE") == .day)
    }

    @Test func quotedLiteralsAreIgnored() {
        // The 'h' inside the literal must not be read as an hour field.
        #expect(TimeGranularity.from(pattern: "HH'h'") == .hour)
        #expect(TimeGranularity.from(pattern: "'seconds' HH:mm") == .minute)
    }

    @Test func analogAlwaysTicksPerMinute() {
        #expect(TimeGranularity.finest(renderMode: .analogClock, format: .custom("HH")) == .minute)
    }

    @Test func systemFormatShowsMinutes() {
        #expect(TimeGranularity.finest(renderMode: .timeOnly, format: .system) == .minute)
    }
}

@Suite struct ClockUpdatePlannerTests {
    let now = utc(2026, 7, 23, 9, 47, 30)
    let utcZone = TimeZone(identifier: "UTC")!

    @Test func minuteAndSecondBoundariesAreGlobal() {
        #expect(ClockUpdatePlanner.nextBoundary(after: now, granularity: .minute, timeZone: utcZone) == utc(2026, 7, 23, 9, 48, 0))
        #expect(ClockUpdatePlanner.nextBoundary(after: now, granularity: .second, timeZone: utcZone) == utc(2026, 7, 23, 9, 47, 31))
    }

    @Test func hourBoundaryShiftsWithFractionalOffset() {
        // Kolkata is +5:30, so its displayed hour flips at :30 past the UTC hour.
        let kolkata = TimeZone(identifier: "Asia/Kolkata")!
        #expect(ClockUpdatePlanner.nextBoundary(after: now, granularity: .hour, timeZone: utcZone) == utc(2026, 7, 23, 10, 0, 0))
        #expect(ClockUpdatePlanner.nextBoundary(after: now, granularity: .hour, timeZone: kolkata) == utc(2026, 7, 23, 10, 30, 0))
    }

    @Test func dayBoundaryIsNextMidnightInZone() {
        #expect(ClockUpdatePlanner.nextBoundary(after: now, granularity: .day, timeZone: utcZone) == utc(2026, 7, 24, 0, 0, 0))
    }

    @Test func nextUpdateIsEarliestAcrossVisibleClocks() {
        let visible = [
            ClockUpdatePlanner.Visible(granularity: .hour, timeZone: utcZone),   // 10:00
            ClockUpdatePlanner.Visible(granularity: .minute, timeZone: utcZone), // 09:48
        ]
        #expect(ClockUpdatePlanner.nextUpdate(after: now, visible: visible) == utc(2026, 7, 23, 9, 48, 0))
    }

    @Test func noVisibleClocksMeansNoTimer() {
        #expect(ClockUpdatePlanner.nextUpdate(after: now, visible: []) == nil)
    }
}

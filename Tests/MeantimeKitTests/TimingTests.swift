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

/// Deadlines must stay strictly in the future even when a local hour repeats or
/// a zone shifts by a fraction of an hour: a past deadline makes the one-shot
/// ticker rearm an already-expired timer and spin. See issue #11.
@Suite struct ClockUpdatePlannerDSTTests {
    let newYork = TimeZone(identifier: "America/New_York")!
    let lordHowe = TimeZone(identifier: "Australia/Lord_Howe")!

    /// 2026-11-01 01:30:30 happens twice in New York: once at -04:00 (EDT) and
    /// again an hour later at -05:00 (EST). Fixtures are absolute UTC instants
    /// so neither occurrence is chosen by an ambiguous component constructor.
    static let firstOccurrence = utc(2026, 11, 1, 5, 30, 30)
    static let secondOccurrence = utc(2026, 11, 1, 6, 30, 30)

    @Test func firstRepeatedHourOccurrenceAdvances() {
        let now = Self.firstOccurrence
        #expect(ClockUpdatePlanner.nextBoundary(after: now, granularity: .second, timeZone: newYork) == utc(2026, 11, 1, 5, 30, 31))
        #expect(ClockUpdatePlanner.nextBoundary(after: now, granularity: .minute, timeZone: newYork) == utc(2026, 11, 1, 5, 31, 0))
        #expect(ClockUpdatePlanner.nextBoundary(after: now, granularity: .hour, timeZone: newYork) == utc(2026, 11, 1, 6, 0, 0))
    }

    @Test func secondRepeatedHourOccurrenceAdvances() {
        let now = Self.secondOccurrence
        #expect(ClockUpdatePlanner.nextBoundary(after: now, granularity: .second, timeZone: newYork) == utc(2026, 11, 1, 6, 30, 31))
        #expect(ClockUpdatePlanner.nextBoundary(after: now, granularity: .minute, timeZone: newYork) == utc(2026, 11, 1, 6, 31, 0))
        #expect(ClockUpdatePlanner.nextBoundary(after: now, granularity: .hour, timeZone: newYork) == utc(2026, 11, 1, 7, 0, 0))
    }

    @Test func repeatedHourBoundaryItselfAdvances() {
        // The exact instant EDT becomes EST: 01:00:00 EST, already seen at 01:00 EDT.
        let now = utc(2026, 11, 1, 6, 0, 0)
        #expect(ClockUpdatePlanner.nextBoundary(after: now, granularity: .hour, timeZone: newYork) == utc(2026, 11, 1, 7, 0, 0))
        #expect(ClockUpdatePlanner.nextBoundary(after: now, granularity: .minute, timeZone: newYork) == utc(2026, 11, 1, 6, 1, 0))
    }

    /// Lord Howe shifts by 30 minutes, so an hour of wall time is not always
    /// 3,600 seconds there. Sweep both transitions at every granularity.
    @Test func fractionalTransitionsNeverReturnAPastDeadline() {
        let transitions = [
            utc(2026, 4, 4, 15, 0, 0),   // +11:00 -> +10:30, repeats 01:30..02:00
            utc(2026, 10, 3, 15, 30, 0), // +10:30 -> +11:00, skips 02:00..02:30
        ]
        for transition in transitions {
            for offset in stride(from: -5_400.0, through: 5_400.0, by: 137.0) {
                let now = transition.addingTimeInterval(offset)
                for granularity in TimeGranularity.allCases {
                    let next = ClockUpdatePlanner.nextBoundary(after: now, granularity: granularity, timeZone: lordHowe)
                    #expect(next > now, "\(granularity) at \(now) returned \(next)")
                }
            }
        }
    }

    @Test func ordinaryOffsetsKeepTheirExactBoundaries() {
        let now = utc(2026, 7, 23, 9, 47, 30)
        let kathmandu = TimeZone(identifier: "Asia/Kathmandu")! // +05:45
        let kolkata = TimeZone(identifier: "Asia/Kolkata")!     // +05:30
        #expect(ClockUpdatePlanner.nextBoundary(after: now, granularity: .hour, timeZone: kathmandu) == utc(2026, 7, 23, 10, 15, 0))
        #expect(ClockUpdatePlanner.nextBoundary(after: now, granularity: .day, timeZone: kolkata) == utc(2026, 7, 23, 18, 30, 0))
    }

    /// Feeding each deadline back as the next `now` must always progress. Before
    /// the fix this stalls inside the repeated hour instead of leaving it.
    @Test func repeatedPlanningAlwaysProgresses() {
        let target = Self.secondOccurrence.addingTimeInterval(60)
        for granularity in TimeGranularity.allCases {
            var now = Self.firstOccurrence.addingTimeInterval(-90)
            var steps = 0
            // Bounded: a stalled planner exhausts the budget instead of looping.
            while now <= target, steps < 5_000 {
                let next = ClockUpdatePlanner.nextBoundary(after: now, granularity: granularity, timeZone: newYork)
                #expect(next > now, "\(granularity) stalled at step \(steps): \(now) -> \(next)")
                now = next
                steps += 1
            }
            #expect(now > target, "\(granularity) never left the repeated hour after \(steps) steps")
        }
    }

    @Test func nextUpdateNeverSchedulesInThePast() {
        let now = Self.secondOccurrence
        let visible = [ClockUpdatePlanner.Visible(granularity: .minute, timeZone: newYork)]
        let next = ClockUpdatePlanner.nextUpdate(after: now, visible: visible, transitions: [now.addingTimeInterval(-60)])
        #expect(next == utc(2026, 11, 1, 6, 31, 0))
    }
}

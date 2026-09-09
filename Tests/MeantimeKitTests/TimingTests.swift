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

/// The accepted UTS-35 vocabulary is wider than the cadence classifier: `a`,
/// `b`, `B` and the zone families change within a day while containing no hour,
/// minute or second field. They used to sit stale until midnight. See #15.
@Suite struct DisplayDependencyTests {
    let newYork = TimeZone(identifier: "America/New_York")!
    let lordHowe = TimeZone(identifier: "Australia/Lord_Howe")!
    let utcZone = TimeZone(identifier: "UTC")!
    let british = Locale(identifier: "en_GB")
    let formatter = ClockFormatter()

    private func dependencies(_ pattern: String) -> DisplayDependencies {
        DisplayDependencies.of(renderMode: .timeOnly, format: .custom(pattern))
    }

    private func change(_ pattern: String, after now: Date, in zone: TimeZone,
                        locale: Locale? = nil) -> Date? {
        ClockUpdatePlanner.nextRenderedChange(after: now, format: .custom(pattern),
                                              timeZone: zone, locale: locale ?? british,
                                              formatter: formatter)
    }

    private func rendered(_ pattern: String, at date: Date, in zone: TimeZone,
                          locale: Locale? = nil) -> String {
        formatter.string(for: date, timeZone: zone, format: .custom(pattern),
                         locale: locale ?? british)
    }

    @Test func fieldFamiliesAreClassified() {
        #expect(dependencies("a").showsDayPeriod)
        #expect(dependencies("B").showsDayPeriod)
        #expect(dependencies("bbbb").showsDayPeriod)
        #expect(!dependencies("HH:mm").showsDayPeriod)
        for zoneField in ["z", "zzzz", "Z", "O", "v", "VV", "XXX", "x"] {
            #expect(dependencies(zoneField).showsZoneDisplay, "\(zoneField)")
        }
        #expect(!dependencies("HH:mm").showsZoneDisplay)
        // Quoted letters are literal text, not fields.
        #expect(!dependencies("'at noon in Zanzibar'").showsDayPeriod)
        #expect(!dependencies("'at noon in Zanzibar'").showsZoneDisplay)
        #expect(dependencies("'it''s' a").showsDayPeriod)
    }

    /// Milliseconds in day moves continuously; the second is the resolution floor.
    @Test func millisecondsInDayTickPerSecondNotFaster() {
        #expect(TimeGranularity.from(pattern: "A") == .second)
        #expect(dependencies("A").granularity == .second)
        #expect(!dependencies("A").needsRenderedComparison)
        let now = utc(2026, 7, 23, 9, 47, 30)
        #expect(ClockUpdatePlanner.nextUpdate(
            after: now, visible: [.init(granularity: .second, timeZone: utcZone)])
            == utc(2026, 7, 23, 9, 47, 31))
    }

    /// A minute or hour field already fires at least as often as a day period or
    /// an offset transition can move, so no rendering comparison is needed.
    @Test func finerFieldsMakeTheRenderedSearchUnnecessary() {
        #expect(!dependencies("h:mm a").needsRenderedComparison)
        #expect(!dependencies("h a").needsRenderedComparison)   // hour boundaries include noon
        #expect(!dependencies("HH:mm z").needsRenderedComparison)
        #expect(dependencies("a").needsRenderedComparison)
        #expect(dependencies("B").needsRenderedComparison)
        #expect(dependencies("z").needsRenderedComparison)
        #expect(dependencies("EEE z").needsRenderedComparison)
        #expect(!dependencies("EEE").needsRenderedComparison)
        #expect(change("h:mm a", after: utc(2026, 7, 23, 9, 0, 0), in: utcZone) == nil)
    }

    @Test func amPmChangesExactlyAtNoonAndMidnight() {
        let morning = utc(2026, 7, 23, 9, 47, 30)
        #expect(change("a", after: morning, in: utcZone) == utc(2026, 7, 23, 12, 0, 0))
        #expect(rendered("a", at: morning, in: utcZone) != rendered("a", at: utc(2026, 7, 23, 12, 0, 0), in: utcZone))

        // In New York the same instant is 05:47, so noon there is 16:00Z.
        #expect(change("a", after: morning, in: newYork) == utc(2026, 7, 23, 16, 0, 0))

        // After noon the next change is the following midnight, which the day
        // boundary also covers: the search still finds it inside its horizon.
        let afternoon = utc(2026, 7, 23, 15, 0, 0)
        #expect(change("a", after: afternoon, in: utcZone) == utc(2026, 7, 24, 0, 0, 0))
    }

    /// Flexible day periods follow the locale's own rules, so the change instant
    /// is found by asking the formatter, never by a table in this app.
    @Test func flexibleDayPeriodsFollowTheLocale() {
        for pattern in ["B", "b", "BBBBB"] {
            for locale in [Locale(identifier: "en_GB"), Locale(identifier: "de_DE"),
                           Locale(identifier: "zh_CN")] {
                let now = utc(2026, 7, 23, 9, 47, 30)
                guard let next = change(pattern, after: now, in: utcZone, locale: locale) else {
                    // A locale with no boundary in the horizon is acceptable only
                    // if the output really is constant for the whole horizon.
                    continue
                }
                #expect(next > now)
                #expect(rendered(pattern, at: next, in: utcZone, locale: locale)
                        != rendered(pattern, at: now, in: utcZone, locale: locale),
                        "\(pattern)/\(locale.identifier)")
                // The change is the *first* one: nothing earlier differs.
                let earlier = next.addingTimeInterval(-60)
                #expect(rendered(pattern, at: earlier, in: utcZone, locale: locale)
                        == rendered(pattern, at: now, in: utcZone, locale: locale),
                        "\(pattern)/\(locale.identifier) changed before \(next)")
            }
        }
    }

    @Test func zoneNamesWakeAtTheirOffsetTransition() {
        // New York leaves daylight saving at 2026-11-01T06:00:00Z.
        let before = utc(2026, 10, 31, 12, 0, 0)
        #expect(change("zzzz", after: before, in: newYork) == utc(2026, 11, 1, 6, 0, 0))
        #expect(change("z", after: before, in: newYork) == utc(2026, 11, 1, 6, 0, 0))
        #expect(change("XXX", after: before, in: newYork) == utc(2026, 11, 1, 6, 0, 0))
        // The exact short name is the locale's business ("EDT" in en_US, "GMT-4"
        // in en_GB); what matters is that it differs across the transition.
        #expect(rendered("z", at: before, in: newYork)
                != rendered("z", at: utc(2026, 11, 1, 6, 0, 0), in: newYork))
        #expect(rendered("z", at: before, in: newYork, locale: Locale(identifier: "en_US")) == "EDT")
        #expect(rendered("z", at: utc(2026, 11, 1, 6, 0, 0), in: newYork,
                         locale: Locale(identifier: "en_US")) == "EST")

        // Lord Howe shifts by 30 minutes and is found the same way.
        #expect(change("XXX", after: utc(2026, 10, 3, 0, 0, 0), in: lordHowe)
                == utc(2026, 10, 3, 15, 30, 0))
    }

    @Test func aZoneThatNeverChangesNeedsNoWakeAndNorDoesAnIdentifier() {
        // A fixed-offset zone has no transitions at all.
        let fixed = TimeZone(secondsFromGMT: 5 * 3_600)!
        #expect(change("XXX", after: utc(2026, 7, 23, 9, 0, 0), in: fixed) == nil)
        #expect(change("z", after: utc(2026, 7, 23, 9, 0, 0), in: utcZone) == nil)
        // The IANA identifier is stable across transitions, so it never expires.
        #expect(change("VV", after: utc(2026, 10, 31, 12, 0, 0), in: newYork) == nil)
        // Literal text has no temporal dependency at all.
        #expect(change("'noon'", after: utc(2026, 7, 23, 9, 0, 0), in: newYork) == nil)
    }

    /// Hourly candidates are taken from the future-safe interval helper, so a
    /// repeated hour advances instead of stalling.
    @Test func candidatesTraverseARepeatedHour() {
        // 01:30:30 EST, the second pass of the New York repeated hour.
        let inside = utc(2026, 11, 1, 6, 30, 30)
        let next = change("a", after: inside, in: newYork)
        #expect(next == utc(2026, 11, 1, 17, 0, 0)) // noon EST
        #expect(rendered("a", at: inside, in: newYork) != rendered("a", at: next!, in: newYork))
    }

    /// A day-period or zone-only clock must not be promoted to a fast cadence.
    @Test func coarsePatternsKeepACoarsePlan() {
        let now = utc(2026, 7, 23, 9, 47, 30)
        for pattern in ["a", "B", "z", "EEE z"] {
            let visible = ClockUpdatePlanner.Visible(
                granularity: dependencies(pattern).granularity, timeZone: utcZone,
                rendered: .init(format: .custom(pattern), locale: british))
            let next = ClockUpdatePlanner.nextUpdate(after: now, visible: [visible],
                                                     formatter: formatter)
            let seconds = next!.timeIntervalSince(now)
            #expect(seconds > 60, "\(pattern) planned a wake in \(seconds) s")
        }
    }

    /// A whole day of planning must progress and stay bounded: the search is a
    /// small candidate set, never a scan of the day's seconds.
    @Test func aDayOfPlanningProgressesAndStaysBounded() {
        let visible = ClockUpdatePlanner.Visible(
            granularity: .day, timeZone: newYork,
            rendered: .init(format: .custom("a"), locale: british))
        var cursor = utc(2026, 10, 31, 12, 0, 0)
        var wakes: [Date] = []
        for _ in 0 ..< 6 {
            guard let next = ClockUpdatePlanner.nextUpdate(after: cursor, visible: [visible],
                                                           formatter: formatter) else { break }
            #expect(next > cursor)
            wakes.append(next)
            cursor = next
        }
        #expect(wakes.count == 6)
        // Six wakes across the fall-back day: noon and midnight only, never hourly.
        for (earlier, later) in zip(wakes, wakes.dropFirst()) {
            #expect(later.timeIntervalSince(earlier) >= 3_600)
        }
    }
}

import Foundation
import Testing
@testable import MeantimeKit

private func utc(_ year: Int, _ month: Int, _ day: Int,
                 _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
}

@Suite struct ClockScheduleTests {
    let newYork = TimeZone(identifier: "America/New_York")!
    // The user's canonical example: NY clock shown 8:00–12:00 and 13:00–17:00 NY time.
    let workday = [
        ActiveWindow(startMinute: 8 * 60, endMinute: 12 * 60),
        ActiveWindow(startMinute: 13 * 60, endMinute: 17 * 60),
    ]

    @Test func emptyScheduleIsAlwaysActive() {
        #expect(ClockSchedule.isActive(at: Date(), windows: [], timeZone: newYork))
    }

    @Test func activeInsideWindowsInTheClocksOwnZone() {
        // 2026-07-23: New York is EDT (UTC−4). 14:00 UTC = 10:00 NY → active.
        #expect(ClockSchedule.isActive(at: utc(2026, 7, 23, 14, 0), windows: workday, timeZone: newYork))
        // 16:30 UTC = 12:30 NY → lunch gap → hidden.
        #expect(!ClockSchedule.isActive(at: utc(2026, 7, 23, 16, 30), windows: workday, timeZone: newYork))
        // 18:00 UTC = 14:00 NY → second window → active.
        #expect(ClockSchedule.isActive(at: utc(2026, 7, 23, 18, 0), windows: workday, timeZone: newYork))
        // 23:00 UTC = 19:00 NY → after hours → hidden.
        #expect(!ClockSchedule.isActive(at: utc(2026, 7, 23, 23, 0), windows: workday, timeZone: newYork))
    }

    @Test func endIsExclusiveStartIsInclusive() {
        let window = [ActiveWindow(startMinute: 8 * 60, endMinute: 12 * 60)]
        #expect(ClockSchedule.isActive(at: utc(2026, 7, 23, 12, 0), windows: window, timeZone: newYork)) // 8:00 NY
        #expect(!ClockSchedule.isActive(at: utc(2026, 7, 23, 16, 0), windows: window, timeZone: newYork)) // 12:00 NY
    }

    @Test func windowWrappingMidnight() {
        let night = [ActiveWindow(startMinute: 22 * 60, endMinute: 6 * 60)]
        #expect(ClockSchedule.isActive(at: utc(2026, 7, 23, 3, 0), windows: night, timeZone: newYork)) // 23:00 NY
        #expect(ClockSchedule.isActive(at: utc(2026, 7, 23, 9, 0), windows: night, timeZone: newYork)) // 05:00 NY
        #expect(!ClockSchedule.isActive(at: utc(2026, 7, 23, 14, 0), windows: night, timeZone: newYork)) // 10:00 NY
    }

    @Test func nextTransitionIsTheNearestEdge() {
        // 10:00 NY (active) → next edge is 12:00 NY = 16:00 UTC.
        let next = ClockSchedule.nextTransition(after: utc(2026, 7, 23, 14, 0),
                                                windows: workday, timeZone: newYork)
        #expect(next == utc(2026, 7, 23, 16, 0))
        // 19:00 NY (after hours) → next edge is tomorrow 8:00 NY = 12:00 UTC.
        let overnight = ClockSchedule.nextTransition(after: utc(2026, 7, 23, 23, 0),
                                                     windows: workday, timeZone: newYork)
        #expect(overnight == utc(2026, 7, 24, 12, 0))
    }

    @Test func noScheduleMeansNoTransition() {
        #expect(ClockSchedule.nextTransition(after: Date(), windows: [], timeZone: newYork) == nil)
    }

    @Test func equalBoundsAreIgnoredAsInvalidInsteadOfMeaningHiddenOrAllDay() {
        let equal = [ActiveWindow(startMinute: 9 * 60, endMinute: 9 * 60)]
        #expect(ClockSchedule.isActive(at: utc(2026, 7, 23, 14, 0),
                                      windows: equal, timeZone: newYork))
        #expect(ClockSchedule.nextTransition(after: utc(2026, 7, 23, 14, 0),
                                             windows: equal, timeZone: newYork) == nil)
    }

    @Test func civilScheduleRemainsCorrectAcrossSpringDSTJump() {
        let window = [ActiveWindow(startMinute: 90, endMinute: 210)]
        #expect(ClockSchedule.isActive(
            at: utc(2026, 3, 8, 6, 45), windows: window, timeZone: newYork))
        #expect(ClockSchedule.isActive(
            at: utc(2026, 3, 8, 7, 15), windows: window, timeZone: newYork))
        #expect(!ClockSchedule.isActive(
            at: utc(2026, 3, 8, 7, 30), windows: window, timeZone: newYork))
    }
}

@Suite struct WeekdayScheduleTests {
    let newYork = TimeZone(identifier: "America/New_York")!
    // The user's canonical split: office hours on weekdays, a later start at
    // the weekend. All times are New York wall-clock time.
    let split = [
        ActiveWindow(days: Weekday.workweek, startMinute: 9 * 60, endMinute: 17 * 60),
        ActiveWindow(days: Weekday.weekend, startMinute: 11 * 60, endMinute: 14 * 60),
    ]

    @Test func eachDaySeesOnlyItsOwnWindow() {
        // Thursday 2026-07-23, 14:00 UTC = 10:00 NY → inside the workweek window.
        #expect(ClockSchedule.isActive(at: utc(2026, 7, 23, 14, 0), windows: split, timeZone: newYork))
        // Thursday 16:00 NY → still the workweek window.
        #expect(ClockSchedule.isActive(at: utc(2026, 7, 23, 20, 0), windows: split, timeZone: newYork))
        // Saturday 2026-07-25, 10:00 NY → before the weekend window starts.
        #expect(!ClockSchedule.isActive(at: utc(2026, 7, 25, 14, 0), windows: split, timeZone: newYork))
        // Saturday 12:00 NY → inside the weekend window.
        #expect(ClockSchedule.isActive(at: utc(2026, 7, 25, 16, 0), windows: split, timeZone: newYork))
        // Saturday 16:00 NY → the workweek window must not leak into Saturday.
        #expect(!ClockSchedule.isActive(at: utc(2026, 7, 25, 20, 0), windows: split, timeZone: newYork))
    }

    @Test func daysAreReadInTheClocksOwnZoneNotTheMacs() {
        // Friday 2026-07-24 23:30 NY is already Saturday 03:30 UTC. A Friday-only
        // window must still be active: the day comes from the clock's zone.
        let friday = [ActiveWindow(days: [.friday], startMinute: 23 * 60, endMinute: 23 * 60 + 59)]
        #expect(ClockSchedule.isActive(at: utc(2026, 7, 25, 3, 30), windows: friday, timeZone: newYork))
    }

    @Test func overnightWindowBelongsToTheDayItStartsOn() {
        // Friday 22:00 → Saturday 06:00, listed on Friday only.
        let nightShift = [ActiveWindow(days: [.friday], startMinute: 22 * 60, endMinute: 6 * 60)]
        // Friday 2026-07-24 23:00 NY = Saturday 03:00 UTC.
        #expect(ClockSchedule.isActive(at: utc(2026, 7, 25, 3, 0), windows: nightShift, timeZone: newYork))
        // Saturday 02:00 NY = 06:00 UTC — still Friday's window.
        #expect(ClockSchedule.isActive(at: utc(2026, 7, 25, 6, 0), windows: nightShift, timeZone: newYork))
        // Saturday 07:00 NY — past the end.
        #expect(!ClockSchedule.isActive(at: utc(2026, 7, 25, 11, 0), windows: nightShift, timeZone: newYork))
        // Saturday 23:00 NY — Saturday is not a listed day, so no second night.
        #expect(!ClockSchedule.isActive(at: utc(2026, 7, 26, 3, 0), windows: nightShift, timeZone: newYork))
    }

    @Test func nextTransitionSkipsDaysWithoutAWindow() {
        // Friday 2026-07-24 18:00 NY, workweek-only window → the next edge is
        // Monday 2026-07-27 09:00 NY (13:00 UTC), three days out.
        let workweek = [ActiveWindow(days: Weekday.workweek, startMinute: 9 * 60, endMinute: 17 * 60)]
        let next = ClockSchedule.nextTransition(after: utc(2026, 7, 24, 22, 0),
                                                windows: workweek, timeZone: newYork)
        #expect(next == utc(2026, 7, 27, 13, 0))
    }

    @Test func nextTransitionFindsAWindowAFullWeekAway() {
        // A Sunday-only window seen on Monday: the edge is six days out, so a
        // scan that only looked at today and tomorrow would find nothing.
        let sunday = [ActiveWindow(days: [.sunday], startMinute: 10 * 60, endMinute: 11 * 60)]
        let next = ClockSchedule.nextTransition(after: utc(2026, 7, 27, 13, 0),
                                                windows: sunday, timeZone: newYork)
        #expect(next == utc(2026, 8, 2, 14, 0)) // Sunday 2026-08-02, 10:00 NY
    }

    @Test func transitionEdgesStayOnWallClockAcrossSpringDST() {
        // 2026-03-08 NY skips 02:00-03:00. A window ending at 03:30 must flip at
        // 03:30 EDT (07:30 UTC), not 210 elapsed minutes after midnight EST.
        let window = [ActiveWindow(startMinute: 90, endMinute: 210)]
        let next = ClockSchedule.nextTransition(after: utc(2026, 3, 8, 6, 45),
                                                windows: window, timeZone: newYork)
        #expect(next == utc(2026, 3, 8, 7, 30))
    }

    @Test func aWindowWithNoDaysIsInvalidAndIgnoredAtRuntime() {
        let empty = ActiveWindow(days: [], startMinute: 9 * 60, endMinute: 17 * 60)
        #expect(ScheduleValidation.issues(in: [empty]) == [.noDays(windowID: empty.id)])
        // Filtered like any other invalid row: no schedule left means always on.
        #expect(ClockSchedule.isActive(at: utc(2026, 7, 23, 23, 0), windows: [empty], timeZone: newYork))
        #expect(ClockSchedule.nextTransition(after: utc(2026, 7, 23, 23, 0),
                                             windows: [empty], timeZone: newYork) == nil)
    }

    @Test func sameHoursOnDifferentDaysDoNotClash() {
        #expect(ScheduleValidation.issues(in: [
            ActiveWindow(days: Weekday.workweek, startMinute: 9 * 60, endMinute: 17 * 60),
            ActiveWindow(days: Weekday.weekend, startMinute: 9 * 60, endMinute: 17 * 60),
        ]).isEmpty)
    }

    @Test func sameHoursOnASharedDayStillClash() {
        let first = ActiveWindow(days: [.monday, .tuesday], startMinute: 9 * 60, endMinute: 17 * 60)
        let second = ActiveWindow(days: [.tuesday, .wednesday], startMinute: 10 * 60, endMinute: 12 * 60)
        #expect(ScheduleValidation.issues(in: [first, second])
            == [.overlap(firstID: first.id, secondID: second.id)])
    }

    @Test func overnightWindowClashesWithTheNextMorning() {
        // Friday 22:00-06:00 spills into Saturday, so a Saturday early window
        // that a per-day comparison would miss must still be reported.
        let night = ActiveWindow(days: [.friday], startMinute: 22 * 60, endMinute: 6 * 60)
        let morning = ActiveWindow(days: [.saturday], startMinute: 5 * 60, endMinute: 8 * 60)
        #expect(ScheduleValidation.issues(in: [night, morning])
            == [.overlap(firstID: night.id, secondID: morning.id)])
    }

    @Test func suggestionOffersTheUnusedDaysAtTheSameHours() throws {
        let existing = [ActiveWindow(days: Weekday.workweek, startMinute: 9 * 60, endMinute: 17 * 60)]
        let suggestion = try #require(ScheduleSuggestion.nextWindow(existing: existing))
        #expect(suggestion.days == Weekday.weekend)
        #expect(suggestion.startMinute == 9 * 60)
        #expect(suggestion.endMinute == 17 * 60)
    }

    @Test func windowStoredBeforePerDaySchedulingRunsEveryDay() throws {
        let legacy = """
        {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","startMinute":480,"endMinute":720}
        """.data(using: .utf8)!
        let window = try JSONDecoder().decode(ActiveWindow.self, from: legacy)
        #expect(window.days == Weekday.everyDay)
    }

    @Test func encodedDayOrderIsStableAndRoundTrips() throws {
        // A `Set` encodes in arbitrary order, which would rewrite stored
        // preferences on every save; the days must come out sorted.
        let window = ActiveWindow(days: [.friday, .monday, .wednesday],
                                  startMinute: 60, endMinute: 120)
        let data = try JSONEncoder().encode(window)
        let object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["days"] as? [Int] == [Weekday.monday, .wednesday, .friday].map(\.rawValue))
        #expect(try JSONDecoder().decode(ActiveWindow.self, from: data) == window)
    }

    @Test func pickerOrderFollowsTheCalendarsFirstWeekday() {
        var american = Calendar(identifier: .gregorian)
        american.firstWeekday = 1
        #expect(Weekday.ordered(for: american).first == .sunday)
        var european = Calendar(identifier: .gregorian)
        european.firstWeekday = 2
        #expect(Weekday.ordered(for: european).first == .monday)
        #expect(Weekday.ordered(for: european).count == 7)
        #expect(Weekday.sunday.previous == .saturday)
    }
}

@Suite struct ScheduleValidationTests {
    @Test func acceptsSeparateAndOvernightWindows() {
        let windows = [
            ActiveWindow(startMinute: 8 * 60, endMinute: 12 * 60),
            ActiveWindow(startMinute: 22 * 60, endMinute: 6 * 60),
        ]
        #expect(ScheduleValidation.issues(in: windows).isEmpty)
    }

    @Test func rejectsEqualDuplicateAndOverlappingWindows() {
        let equal = ActiveWindow(startMinute: 9 * 60, endMinute: 9 * 60)
        #expect(ScheduleValidation.issues(in: [equal]) == [.equalBounds(windowID: equal.id)])

        let first = ActiveWindow(startMinute: 8 * 60, endMinute: 12 * 60)
        let duplicate = ActiveWindow(startMinute: 8 * 60, endMinute: 12 * 60)
        #expect(ScheduleValidation.issues(in: [first, duplicate])
            == [.duplicate(firstID: first.id, secondID: duplicate.id)])

        let overlap = ActiveWindow(startMinute: 11 * 60, endMinute: 14 * 60)
        #expect(ScheduleValidation.issues(in: [first, overlap])
            == [.overlap(firstID: first.id, secondID: overlap.id)])
    }

    @Test func touchingWindowsDoNotOverlap() {
        let morning = ActiveWindow(startMinute: 8 * 60, endMinute: 12 * 60)
        let afternoon = ActiveWindow(startMinute: 12 * 60, endMinute: 17 * 60)
        #expect(ScheduleValidation.issues(in: [morning, afternoon]).isEmpty)
    }

    @Test func nextSuggestionAvoidsExistingWindows() throws {
        let existing = [
            ActiveWindow(startMinute: 8 * 60, endMinute: 12 * 60),
            ActiveWindow(startMinute: 13 * 60, endMinute: 17 * 60),
        ]

        let suggestion = try #require(ScheduleSuggestion.nextWindow(existing: existing))

        #expect(ScheduleValidation.issues(in: existing + [suggestion]).isEmpty)
        #expect(suggestion.startMinute != suggestion.endMinute)
    }
}

@Suite struct WorldClockMigrationTests {
    @Test func decodesV1PayloadWithoutNewFields() throws {
        // Exactly what 1.0.0 persisted: no activeWindows key.
        let v1 = """
        {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","timeZoneID":"Asia/Tokyo",
         "customLabel":"Office","renderMode":"timeOnly","isPinned":false}
        """.data(using: .utf8)!
        let clock = try JSONDecoder().decode(WorldClock.self, from: v1)
        #expect(clock.customLabel == "Office")
        #expect(clock.renderMode == .timeOnly)
        #expect(clock.isPinned == false)
        #expect(clock.activeWindows.isEmpty)
        #expect(clock.adornmentStyle == .flag)
        #expect(clock.customText == nil)
    }

    @Test func legacyCustomEmojiMigratesToEmojiAdornment() throws {
        let legacy = """
        {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","timeZoneID":"Asia/Tokyo",
         "customEmoji":"🏯","renderMode":"flagAndTime","isPinned":true}
        """.data(using: .utf8)!
        let clock = try JSONDecoder().decode(WorldClock.self, from: legacy)
        #expect(clock.adornmentStyle == .emoji)
        #expect(clock.displayAdornment == "🏯")
    }

    @Test func scheduledVisibilityGovernsMenuBarPresence() {
        var clock = WorldClock(timeZoneID: "America/New_York",
                               activeWindows: [ActiveWindow(startMinute: 8 * 60, endMinute: 12 * 60)])
        #expect(clock.isActiveInMenuBar(at: utc(2026, 7, 23, 14, 0)))   // 10:00 NY
        #expect(!clock.isActiveInMenuBar(at: utc(2026, 7, 23, 23, 0)))  // 19:00 NY
        clock.isPinned = false
        #expect(!clock.isActiveInMenuBar(at: utc(2026, 7, 23, 14, 0)))  // unpinned wins
    }
}

@Suite struct PlannerTransitionTests {
    let utcZone = TimeZone(identifier: "UTC")!

    @Test func transitionCanBeTheEarliestWake() {
        let now = utc(2026, 7, 23, 9, 47)
        let transition = utc(2026, 7, 23, 9, 50)
        // Hour granularity alone would wake at 10:00; the transition wins.
        let visible = [ClockUpdatePlanner.Visible(granularity: .hour, timeZone: utcZone)]
        let next = ClockUpdatePlanner.nextUpdate(after: now, visible: visible,
                                                 transitions: [transition])
        #expect(next == transition)
    }

    @Test func transitionAloneStillSchedulesAWake() {
        let now = utc(2026, 7, 23, 9, 0)
        let transition = utc(2026, 7, 23, 12, 0)
        #expect(ClockUpdatePlanner.nextUpdate(after: now, visible: [], transitions: [transition]) == transition)
    }

    @Test func pastTransitionsAreIgnored() {
        let now = utc(2026, 7, 23, 9, 0)
        let past = utc(2026, 7, 23, 8, 0)
        #expect(ClockUpdatePlanner.nextUpdate(after: now, visible: [], transitions: [past]) == nil)
    }
}

@Suite struct ZoneOffsetTests {
    @Test func wholeAndFractionalOffsets() {
        let date = utc(2026, 7, 23, 12, 0, 0)
        #expect(ZoneOffset.caption(for: TimeZone(identifier: "UTC")!, at: date) == "GMT")
        #expect(ZoneOffset.caption(for: TimeZone(identifier: "America/Sao_Paulo")!, at: date) == "GMT−3")
        #expect(ZoneOffset.caption(for: TimeZone(identifier: "Asia/Kolkata")!, at: date) == "GMT+5:30")
        // DST-aware: New York in July is −4, not −5.
        #expect(ZoneOffset.caption(for: TimeZone(identifier: "America/New_York")!, at: date) == "GMT−4")
    }
}

@Suite struct TimeTravelTests {
    @Test func combinesDayAndTimeInZone() {
        let utcZone = TimeZone(identifier: "UTC")!
        let day = utc(2026, 12, 25, 3, 3, 3)
        let time = utc(2026, 1, 1, 14, 30, 0)
        let combined = TimeTravel.combine(day: day, time: time, timeZone: utcZone)
        #expect(combined == utc(2026, 12, 25, 14, 30, 0))
    }

    @Test func sameMinuteIgnoresSecondsWithinAMinute() {
        let utcZone = TimeZone(identifier: "UTC")!
        // Seconds differ, minute is the same: treated as the same minute so the
        // panel drops the redundant "Previewing" state when the preview equals now.
        #expect(TimeTravel.sameMinute(utc(2026, 7, 24, 17, 39, 0),
                                      utc(2026, 7, 24, 17, 39, 59), timeZone: utcZone))
    }

    @Test func sameMinuteSeparatesAcrossTheMinuteBoundary() {
        let utcZone = TimeZone(identifier: "UTC")!
        #expect(!TimeTravel.sameMinute(utc(2026, 7, 24, 17, 39, 59),
                                       utc(2026, 7, 24, 17, 40, 0), timeZone: utcZone))
        #expect(!TimeTravel.sameMinute(utc(2026, 7, 24, 17, 39, 0),
                                       utc(2026, 7, 25, 17, 39, 0), timeZone: utcZone))
    }

    @Test func sameMinuteIsEvaluatedInTheGivenZone() {
        // The same instant is a different wall-clock minute in a half-hour zone.
        let instant = utc(2026, 7, 24, 12, 0, 0)
        let kolkata = TimeZone(identifier: "Asia/Kolkata")! // +5:30
        #expect(TimeTravel.sameMinute(instant, instant, timeZone: kolkata))
        #expect(!TimeTravel.sameMinute(instant, instant.addingTimeInterval(60), timeZone: kolkata))
    }
}

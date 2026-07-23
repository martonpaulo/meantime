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
}

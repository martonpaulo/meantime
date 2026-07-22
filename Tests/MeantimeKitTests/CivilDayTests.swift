import Foundation
import Testing
@testable import MeantimeKit

private func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

@Suite struct CivilDayTests {
    let la = TimeZone(identifier: "America/Los_Angeles")!
    let sydney = TimeZone(identifier: "Australia/Sydney")!

    @Test func targetAheadIsPositive() {
        // 2026-07-23 20:00 UTC → LA is 13:00 Jul 23, Sydney is 06:00 Jul 24.
        let moment = utc(2026, 7, 23, 20, 0)
        #expect(CivilDay.offset(at: moment, reference: la, target: sydney) == 1)
        #expect(CivilDay.offset(at: moment, reference: sydney, target: la) == -1)
    }

    @Test func sameDayIsZero() {
        let moment = utc(2026, 7, 23, 12, 0) // midday UTC, both zones on the 23rd/24th? check same-zone
        #expect(CivilDay.offset(at: moment, reference: la, target: la) == 0)
    }
}

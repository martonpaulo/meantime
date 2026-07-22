import Foundation
import Testing
@testable import MeantimeKit

@Suite struct WorldClockTests {
    @Test func labelFallsBackToCityThenHonorsOverride() {
        var clock = WorldClock(timeZoneID: "America/Sao_Paulo")
        #expect(clock.displayLabel == "Sao Paulo")
        clock.customLabel = "Home"
        #expect(clock.displayLabel == "Home")
        clock.customLabel = "   " // blank override is ignored
        #expect(clock.displayLabel == "Sao Paulo")
    }

    @Test func emojiFallsBackToFlagThenHonorsOverride() {
        var clock = WorldClock(timeZoneID: "America/Los_Angeles")
        #expect(clock.displayEmoji == "🇺🇸")
        clock.customEmoji = "🏠"
        #expect(clock.displayEmoji == "🏠")
    }

    @Test func invalidIdentifierResolvesToCurrentZone() {
        let clock = WorldClock(timeZoneID: "Not/AZone")
        #expect(clock.timeZone == TimeZone.current)
    }

    @Test func codableRoundTrips() throws {
        let clock = WorldClock(timeZoneID: "Europe/Oslo", customLabel: "Team",
                               customEmoji: "🧑‍💻", renderMode: .timeOnly, isPinned: false)
        let data = try JSONEncoder().encode(clock)
        let decoded = try JSONDecoder().decode(WorldClock.self, from: data)
        #expect(decoded == clock)
    }
}

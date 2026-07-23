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

    @Test func adornmentSupportsFlagEmojiTextAndNone() {
        var clock = WorldClock(timeZoneID: "America/Los_Angeles")
        #expect(clock.adornmentStyle == .flag)
        #expect(clock.displayAdornment == "🇺🇸")

        clock.customEmoji = "🏠"
        clock.adornmentStyle = .emoji
        #expect(clock.displayAdornment == "🏠")

        clock.customText = "LA"
        clock.adornmentStyle = .text
        #expect(clock.displayAdornment == "LA")

        clock.adornmentStyle = .none
        #expect(clock.displayAdornment == nil)
    }

    @Test func restoringDefaultsPreservesIdentityAndZone() {
        let id = UUID()
        let customized = WorldClock(
            id: id,
            timeZoneID: "America/New_York",
            customLabel: "Office",
            customEmoji: "🏢",
            customText: "NYC",
            adornmentStyle: .text,
            renderMode: .timeOnly,
            isPinned: false,
            activeWindows: [ActiveWindow(startMinute: 480, endMinute: 720)])

        let restored = customized.restoredToDefaults()

        #expect(restored.id == id)
        #expect(restored.timeZoneID == "America/New_York")
        #expect(restored.customLabel == nil)
        #expect(restored.customEmoji == nil)
        #expect(restored.customText == nil)
        #expect(restored.adornmentStyle == .flag)
        #expect(restored.renderMode == .flagAndTime)
        #expect(restored.isPinned)
        #expect(restored.activeWindows.isEmpty)
    }

    @Test func invalidIdentifierResolvesToCurrentZone() {
        let clock = WorldClock(timeZoneID: "Not/AZone")
        #expect(clock.timeZone == TimeZone.current)
    }

    @Test func codableRoundTrips() throws {
        let clock = WorldClock(timeZoneID: "Europe/Oslo", customLabel: "Team",
                               customEmoji: "🧑‍💻", customText: "OSL",
                               adornmentStyle: .text, renderMode: .timeOnly,
                               isPinned: false)
        let data = try JSONEncoder().encode(clock)
        let decoded = try JSONDecoder().decode(WorldClock.self, from: data)
        #expect(decoded == clock)
    }
}

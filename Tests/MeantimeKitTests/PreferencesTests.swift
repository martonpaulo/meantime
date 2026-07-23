import Foundation
import Testing
@testable import MeantimeKit

/// In-memory stand-in for UserDefaults so persistence is verifiable in isolation.
private final class MemoryStore: PreferenceStore {
    private var values: [String: Any] = [:]
    func data(forKey defaultName: String) -> Data? { values[defaultName] as? Data }
    func double(forKey defaultName: String) -> Double { values[defaultName] as? Double ?? 0 }
    func object(forKey defaultName: String) -> Any? { values[defaultName] }
    func set(_ value: Any?, forKey defaultName: String) { values[defaultName] = value }
    func removeObject(forKey defaultName: String) { values[defaultName] = nil }
}

@Suite @MainActor struct PreferencesTests {
    @Test func emptyStoreYieldsDefaults() {
        let prefs = Preferences(store: MemoryStore())
        #expect(prefs.timeFormat == PreferenceDefaults.timeFormat)
        #expect(prefs.textSize == PreferenceDefaults.textSize)
        #expect(prefs.elementSpacing == PreferenceDefaults.elementSpacing)
        #expect(prefs.combinedSeparator == PreferenceDefaults.combinedSeparator)
        #expect(prefs.clocks.count == 1) // seeded with the current zone
    }

    @Test func mutationsPersistWriteThrough() {
        let store = MemoryStore()
        let prefs = Preferences(store: store)
        prefs.addClock(WorldClock(timeZoneID: "Asia/Tokyo", customLabel: "Office"))
        prefs.timeFormat = .custom("HH:mm")
        prefs.textSize = 16
        prefs.combinedSeparator = "·"

        // A fresh instance backed by the same store must observe the writes.
        let reloaded = Preferences(store: store)
        #expect(reloaded.clocks.contains { $0.timeZoneID == "Asia/Tokyo" })
        #expect(reloaded.timeFormat == .custom("HH:mm"))
        #expect(reloaded.textSize == 16)
        #expect(reloaded.combinedSeparator == "·")
    }

    @Test func restoreDefaultsResetsEverything() {
        let store = MemoryStore()
        let prefs = Preferences(store: store)
        prefs.addClock(WorldClock(timeZoneID: "Asia/Tokyo"))
        prefs.timeFormat = .custom("h:mm a")
        prefs.textSize = 17
        prefs.elementSpacing = 10
        prefs.combinedSeparator = ""

        prefs.restoreDefaults()

        #expect(prefs.timeFormat == PreferenceDefaults.timeFormat)
        #expect(prefs.textSize == PreferenceDefaults.textSize)
        #expect(prefs.elementSpacing == PreferenceDefaults.elementSpacing)
        #expect(prefs.combinedSeparator == PreferenceDefaults.combinedSeparator)
        #expect(prefs.clocks.count == 1)
        // And the reset is persisted, not just in memory.
        #expect(Preferences(store: store).clocks.count == 1)
    }

    @Test func moveClockNudgesWithinBounds() {
        let prefs = Preferences(store: MemoryStore())
        prefs.clocks = [WorldClock(timeZoneID: "Asia/Tokyo"),
                        WorldClock(timeZoneID: "Europe/Paris"),
                        WorldClock(timeZoneID: "America/Lima")]
        let paris = prefs.clocks[1].id
        prefs.moveClock(id: paris, by: -1)
        #expect(prefs.clocks[0].id == paris)
        prefs.moveClock(id: paris, by: -1) // already first: no-op
        #expect(prefs.clocks[0].id == paris)
        prefs.moveClock(id: paris, by: 1)
        #expect(prefs.clocks[1].id == paris)
    }

    @Test func updateReplacesMatchingClock() {
        let prefs = Preferences(store: MemoryStore())
        var clock = WorldClock(timeZoneID: "Europe/Paris")
        prefs.addClock(clock)
        clock.customLabel = "Paris Team"
        prefs.update(clock)
        #expect(prefs.clocks.last?.customLabel == "Paris Team")
    }
}

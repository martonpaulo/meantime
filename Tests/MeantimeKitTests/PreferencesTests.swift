import Foundation
import Testing
@testable import MeantimeKit

/// In-memory stand-in for UserDefaults so persistence is verifiable in isolation.
final class TestPreferenceStore: PreferenceStore {
    private var values: [String: Any] = [:]
    private(set) var setCount = 0
    func data(forKey defaultName: String) -> Data? { values[defaultName] as? Data }
    func double(forKey defaultName: String) -> Double { values[defaultName] as? Double ?? 0 }
    func object(forKey defaultName: String) -> Any? { values[defaultName] }
    func set(_ value: Any?, forKey defaultName: String) {
        setCount += 1
        values[defaultName] = value
    }
    func removeObject(forKey defaultName: String) { values[defaultName] = nil }
    func seed(_ value: Any?, forKey key: String) { values[key] = value }
}

@Suite @MainActor struct PreferencesTests {
    @Test func emptyStoreYieldsDefaults() {
        let prefs = Preferences(store: TestPreferenceStore())
        #expect(prefs.timeFormat == PreferenceDefaults.timeFormat)
        #expect(prefs.textSize == PreferenceDefaults.textSize)
        #expect(prefs.elementSpacing == PreferenceDefaults.elementSpacing)
        #expect(prefs.combinedSeparator == PreferenceDefaults.combinedSeparator)
        #expect(prefs.clocks.count == 1) // seeded with the current zone
    }

    @Test func mutationsPersistWriteThrough() {
        let store = TestPreferenceStore()
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
        let store = TestPreferenceStore()
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
        let prefs = Preferences(store: TestPreferenceStore())
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
        let prefs = Preferences(store: TestPreferenceStore())
        var clock = WorldClock(timeZoneID: "Europe/Paris")
        prefs.addClock(clock)
        clock.customLabel = "Paris Team"
        prefs.update(clock)
        #expect(prefs.clocks.last?.customLabel == "Paris Team")
    }

    @Test func removingClockPersistsWriteThrough() {
        let store = TestPreferenceStore()
        let prefs = Preferences(store: store)
        let clock = WorldClock(timeZoneID: "Asia/Tokyo")
        prefs.addClock(clock)

        prefs.removeClock(id: clock.id)

        #expect(!prefs.clocks.contains { $0.id == clock.id })
        #expect(!Preferences(store: store).clocks.contains { $0.id == clock.id })
    }

    @Test func removingMultipleClocksByIDPreservesUnselectedClocks() {
        let store = TestPreferenceStore()
        let prefs = Preferences(store: store)
        let tokyo = WorldClock(timeZoneID: "Asia/Tokyo")
        let sydney = WorldClock(timeZoneID: "Australia/Sydney")
        let paris = WorldClock(timeZoneID: "Europe/Paris")
        prefs.clocks = [tokyo, sydney, paris]

        prefs.removeClocks(ids: [tokyo.id, paris.id])

        #expect(prefs.clocks == [sydney])
        #expect(Preferences(store: store).clocks == [sydney])
    }

    @Test func appearanceAppliesAndPersistsWithOneStoreWrite() {
        let store = TestPreferenceStore()
        let prefs = Preferences(store: store)
        let appearance = MenuBarAppearance(
            timeFormat: .custom("HH:mm"),
            layout: .combined,
            combinedSeparator: "·",
            textSize: 16,
            elementSpacing: 7)

        prefs.applyAppearance(appearance)

        #expect(prefs.appearance == appearance)
        #expect(store.setCount == 1)
        #expect(Preferences(store: store).appearance == appearance)
    }

    @Test func legacyAppearanceKeysMigrateWithoutChangingValues() {
        let store = TestPreferenceStore()
        store.seed("combined", forKey: "menuBarLayout.v1")
        store.seed(16.0, forKey: "textSize")
        store.seed(7.0, forKey: "elementSpacing")
        store.seed("", forKey: "combinedSeparator")
        store.seed(try? JSONEncoder().encode(TimeFormat.custom("h:mm a")),
                   forKey: "timeFormat.v1")

        let prefs = Preferences(store: store)

        #expect(prefs.appearance == MenuBarAppearance(
            timeFormat: .custom("h:mm a"),
            layout: .combined,
            combinedSeparator: "",
            textSize: 16,
            elementSpacing: 7))
    }
}

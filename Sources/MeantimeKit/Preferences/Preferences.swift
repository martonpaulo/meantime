import Foundation
import Observation

/// The single source of truth for every user preference. Every fallback lives in
/// `PreferenceDefaults` and nowhere else. Persistence is write-through: mutating
/// a property (directly or via a SwiftUI binding) saves it immediately.
///
/// The login-at-startup state is intentionally *not* stored here — the system
/// owns it (see the app's login-item helper), so mirroring it would create a
/// second source of truth.
@MainActor
@Observable
public final class Preferences {
    @ObservationIgnored private let store: PreferenceStore

    public var clocks: [WorldClock] {
        didSet { save(clocks, forKey: Key.clocks) }
    }

    public var timeFormat: TimeFormat {
        didSet { save(timeFormat, forKey: Key.timeFormat) }
    }

    /// Font size, in points, for menu-bar and panel time text.
    public var textSize: Double {
        didSet { store.set(textSize, forKey: Key.textSize) }
    }

    /// Gap, in points, between an item's emoji and its time (and around items).
    public var elementSpacing: Double {
        didSet { store.set(elementSpacing, forKey: Key.elementSpacing) }
    }

    public init(store: PreferenceStore = UserDefaults.standard) {
        self.store = store
        self.clocks = Self.decode([WorldClock].self, forKey: Key.clocks, from: store)
            ?? PreferenceDefaults.clocks
        self.timeFormat = Self.decode(TimeFormat.self, forKey: Key.timeFormat, from: store)
            ?? PreferenceDefaults.timeFormat
        self.textSize = Self.readDouble(Key.textSize, from: store)
            ?? PreferenceDefaults.textSize
        self.elementSpacing = Self.readDouble(Key.elementSpacing, from: store)
            ?? PreferenceDefaults.elementSpacing
    }

    // MARK: Clock editing

    public func addClock(_ clock: WorldClock) {
        clocks.append(clock)
    }

    public func removeClocks(at offsets: IndexSet) {
        clocks = clocks.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)
    }

    public func removeClock(id: WorldClock.ID) {
        clocks.removeAll { $0.id == id }
    }

    /// Reorders clocks with SwiftUI `onMove` semantics (Foundation-only, since
    /// the kit does not depend on SwiftUI): `destination` is an index in the
    /// pre-move array before which the moved items are inserted.
    public func moveClocks(from source: IndexSet, to destination: Int) {
        let moving = source.sorted().map { clocks[$0] }
        let insertion = destination - source.filter { $0 < destination }.count
        var result = clocks
        for index in source.sorted(by: >) { result.remove(at: index) }
        result.insert(contentsOf: moving, at: insertion)
        clocks = result
    }

    /// Replaces the clock with the same id, if present.
    public func update(_ clock: WorldClock) {
        guard let index = clocks.firstIndex(where: { $0.id == clock.id }) else { return }
        clocks[index] = clock
    }

    // MARK: Restore Defaults

    /// Resets configurable preferences to their defaults. Does not touch the
    /// login item, permissions, or any non-preference state.
    public func restoreDefaults() {
        clocks = PreferenceDefaults.clocks
        timeFormat = PreferenceDefaults.timeFormat
        textSize = PreferenceDefaults.textSize
        elementSpacing = PreferenceDefaults.elementSpacing
    }

    // MARK: Persistence helpers

    private func save<Value: Encodable>(_ value: Value, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        store.set(data, forKey: key)
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, forKey key: String,
                                                 from store: PreferenceStore) -> Value? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    private static func readDouble(_ key: String, from store: PreferenceStore) -> Double? {
        store.object(forKey: key) == nil ? nil : store.double(forKey: key)
    }

    private enum Key {
        static let clocks = "clocks.v1"
        static let timeFormat = "timeFormat.v1"
        static let textSize = "textSize"
        static let elementSpacing = "elementSpacing"
    }
}

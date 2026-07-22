import Foundation

/// A user-configured reference to one time zone. Pure data; presentation is
/// resolved lazily so an empty label/emoji always falls back to a sensible
/// default derived from the zone.
public struct WorldClock: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    /// IANA identifier, e.g. `America/Sao_Paulo`.
    public var timeZoneID: String
    /// User label. When empty, a humanized city name is shown.
    public var customLabel: String?
    /// User emoji. When empty, the zone's region flag is shown.
    public var customEmoji: String?
    /// How this clock draws when it has its own menu-bar item.
    public var renderMode: ClockRenderMode
    /// Whether this clock gets a dedicated menu-bar item.
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        timeZoneID: String,
        customLabel: String? = nil,
        customEmoji: String? = nil,
        renderMode: ClockRenderMode = .flagAndTime,
        isPinned: Bool = true
    ) {
        self.id = id
        self.timeZoneID = timeZoneID
        self.customLabel = customLabel
        self.customEmoji = customEmoji
        self.renderMode = renderMode
        self.isPinned = isPinned
    }

    /// The resolved time zone, or the current zone if the identifier is invalid.
    public var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    /// The name to show: the custom label, else a humanized city name.
    public var displayLabel: String {
        if let trimmed = customLabel?.meantime_trimmed, !trimmed.isEmpty { return trimmed }
        return CityLabel.name(for: timeZoneID)
    }

    /// The glyph to show before the time: the custom emoji, else the region flag.
    public var displayEmoji: String {
        if let trimmed = customEmoji?.meantime_trimmed, !trimmed.isEmpty { return trimmed }
        return RegionFlag.emoji(for: timeZoneID)
    }
}

extension String {
    /// Whitespace-trimmed copy. Named to avoid colliding with app-side helpers.
    var meantime_trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

import Foundation

/// A user-configured reference to one time zone. Pure data; presentation is
/// resolved lazily so an empty label falls back to a sensible default derived
/// from the zone.
public struct WorldClock: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    /// IANA identifier, e.g. `America/Sao_Paulo`.
    public var timeZoneID: String
    /// User label. When empty, a humanized city name is shown.
    public var customLabel: String?
    /// User emoji retained independently when another adornment mode is active.
    public var customEmoji: String?
    /// User text shown before the clock when `adornmentStyle` is `.text`.
    public var customText: String?
    /// The kind of content shown before the clock.
    public var adornmentStyle: ClockAdornmentStyle
    /// How this clock draws when it has its own menu-bar item.
    public var renderMode: ClockRenderMode
    /// Whether this clock gets a dedicated menu-bar item.
    public var isPinned: Bool
    /// Daily menu-bar visibility windows in the clock's own zone.
    /// Empty = always visible (see `ClockSchedule`).
    public var activeWindows: [ActiveWindow]

    public init(
        id: UUID = UUID(),
        timeZoneID: String,
        customLabel: String? = nil,
        customEmoji: String? = nil,
        customText: String? = nil,
        adornmentStyle: ClockAdornmentStyle = .flag,
        renderMode: ClockRenderMode = .flagAndTime,
        isPinned: Bool = true,
        activeWindows: [ActiveWindow] = []
    ) {
        self.id = id
        self.timeZoneID = timeZoneID
        self.customLabel = customLabel
        self.customEmoji = customEmoji
        self.customText = customText
        self.adornmentStyle = adornmentStyle
        self.renderMode = renderMode
        self.isPinned = isPinned
        self.activeWindows = activeWindows
    }

    /// Backward-compatible decoding: fields added after 1.0 fall back to their
    /// defaults so previously persisted clocks survive upgrades untouched.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timeZoneID = try container.decode(String.self, forKey: .timeZoneID)
        customLabel = try container.decodeIfPresent(String.self, forKey: .customLabel)
        customEmoji = try container.decodeIfPresent(String.self, forKey: .customEmoji)
        customText = try container.decodeIfPresent(String.self, forKey: .customText)
        adornmentStyle = try container.decodeIfPresent(ClockAdornmentStyle.self, forKey: .adornmentStyle)
            ?? (customEmoji?.meantime_trimmed.isEmpty == false ? .emoji : .flag)
        renderMode = try container.decodeIfPresent(ClockRenderMode.self, forKey: .renderMode) ?? .flagAndTime
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? true
        activeWindows = try container.decodeIfPresent([ActiveWindow].self, forKey: .activeWindows) ?? []
    }

    /// Whether this clock's menu-bar item is visible right now.
    public func isActiveInMenuBar(at date: Date) -> Bool {
        isPinned && ClockSchedule.isActive(at: date, windows: activeWindows, timeZone: timeZone)
    }

    /// The resolved time zone, or the current zone if the identifier is invalid.
    public var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    /// The name to show: the custom label, else a humanized city name.
    public var displayLabel: String {
        if let trimmed = customLabel?.meantime_trimmed, !trimmed.isEmpty { return trimmed }
        return CityLabel.name(for: timeZoneID)
    }

    /// The resolved content to show before the clock, or nil when explicitly
    /// disabled. Empty custom values stay empty so Save can reject them instead
    /// of silently changing the user's selected mode.
    public var displayAdornment: String? {
        switch adornmentStyle {
        case .flag:
            return RegionFlag.emoji(for: timeZoneID)
        case .emoji:
            return customEmoji?.meantime_trimmed.nonEmpty
        case .text:
            return customText?.meantime_trimmed.nonEmpty
        case .none:
            return nil
        }
    }

    /// Restores every configurable per-clock preference while preserving the
    /// clock's identity and time-zone reference.
    public func restoredToDefaults() -> WorldClock {
        WorldClock(id: id, timeZoneID: timeZoneID)
    }
}

extension String {
    /// Whitespace-trimmed copy. Named to avoid colliding with app-side helpers.
    var meantime_trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    fileprivate var nonEmpty: String? { isEmpty ? nil : self }
}

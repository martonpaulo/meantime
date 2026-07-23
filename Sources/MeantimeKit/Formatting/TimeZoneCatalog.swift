import Foundation

/// The searchable list of addable time zones, prepared for presentation:
/// city-labeled, grouped by region, with a current GMT offset. Pure data —
/// views filter and draw it.
public enum TimeZoneCatalog {
    public struct Entry: Identifiable, Hashable, Sendable {
        /// IANA identifier, e.g. `America/Sao_Paulo`.
        public let id: String
        public let city: String
        /// Top-level region: `America`, `Europe`, …
        public let region: String
        public let offsetSeconds: Int

        public init(id: String, city: String, region: String, offsetSeconds: Int) {
            self.id = id
            self.city = city
            self.region = region
            self.offsetSeconds = offsetSeconds
        }
    }

    /// Region display order: the familiar continents, then the oceanic rest.
    public static let regionOrder = [
        "America", "Europe", "Asia", "Africa", "Australia",
        "Pacific", "Atlantic", "Indian", "Antarctica", "Arctic",
    ]

    /// City-bearing zones (drops `Etc/*` and bare aliases like `UTC` or `GMT`,
    /// which are not places anyone schedules around), sorted by city.
    public static func entries(at date: Date = Date()) -> [Entry] {
        TimeZone.knownTimeZoneIdentifiers.compactMap { identifier -> Entry? in
            let parts = identifier.split(separator: "/")
            guard parts.count >= 2, let region = parts.first, region != "Etc",
                  let zone = TimeZone(identifier: identifier) else { return nil }
            return Entry(id: identifier,
                         city: CityLabel.name(for: identifier),
                         region: String(region),
                         offsetSeconds: zone.secondsFromGMT(for: date))
        }
        .sorted { $0.city.localizedCaseInsensitiveCompare($1.city) == .orderedAscending }
    }

    /// Case- and diacritic-insensitive match on city or identifier.
    public static func matches(_ entry: Entry, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        return entry.city.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            || entry.id.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

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
        public let searchTerms: [String]

        public init(id: String, city: String, region: String, offsetSeconds: Int,
                    searchTerms: [String] = []) {
            self.id = id
            self.city = city
            self.region = region
            self.offsetSeconds = offsetSeconds
            self.searchTerms = searchTerms
        }
    }

    public static let universalRegion = "Universal & Fixed Offsets"

    private static let fixedOffsetIdentifiers = Set(
        ["Etc/GMT"]
            + (1...12).map { "Etc/GMT+\($0)" }
            + (1...14).map { "Etc/GMT-\($0)" }
    )

    /// Region display order: the familiar continents, then the oceanic rest.
    public static let regionOrder = [
        "America", "Europe", "Asia", "Africa", "Australia",
        "Pacific", "Atlantic", "Indian", "Antarctica", "Arctic",
        universalRegion,
    ]

    /// Every system time-zone identifier, with place zones grouped by continent
    /// and aliases/fixed offsets in one explicit universal group.
    public static func entries(at date: Date = Date()) -> [Entry] {
        let identifiers = Set(TimeZone.knownTimeZoneIdentifiers)
            .union(["UTC", "GMT"])
            .union(fixedOffsetIdentifiers)
        return identifiers.compactMap { identifier -> Entry? in
            let parts = identifier.split(separator: "/")
            guard let zone = TimeZone(identifier: identifier) else { return nil }
            let candidateRegion = parts.first.map(String.init)
            let region = candidateRegion.flatMap {
                regionOrder.dropLast().contains($0) ? $0 : nil
            } ?? universalRegion
            let localizedName = zone.localizedName(for: .generic, locale: .current)
            let abbreviation = zone.abbreviation(for: date)
            return Entry(id: identifier,
                         city: CityLabel.name(for: identifier),
                         region: region,
                         offsetSeconds: zone.secondsFromGMT(for: date),
                         searchTerms: [localizedName, abbreviation].compactMap { $0 })
        }
        .sorted {
            let leftRegion = regionOrder.firstIndex(of: $0.region) ?? .max
            let rightRegion = regionOrder.firstIndex(of: $1.region) ?? .max
            if leftRegion != rightRegion { return leftRegion < rightRegion }
            return $0.city.localizedCaseInsensitiveCompare($1.city) == .orderedAscending
        }
    }

    /// Case- and diacritic-insensitive match on city or identifier.
    public static func matches(_ entry: Entry, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        return entry.city.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            || entry.id.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            || entry.searchTerms.contains {
                $0.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
    }
}

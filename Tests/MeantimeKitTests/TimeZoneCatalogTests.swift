import Foundation
import Testing
@testable import MeantimeKit

@Suite struct TimeZoneCatalogTests {
    let entries = TimeZoneCatalog.entries()

    @Test func includesPlaceUniversalAndFixedOffsetZones() {
        #expect(entries.contains { $0.id.hasPrefix("Etc/") })
        #expect(entries.contains { $0.id == "UTC" })
        #expect(entries.contains { $0.id == "GMT" })
        #expect(entries.contains { $0.id == "America/Sao_Paulo" })
    }

    @Test func entriesCarryRegionAndCity() {
        let saoPaulo = entries.first { $0.id == "America/Sao_Paulo" }
        #expect(saoPaulo?.city == "Sao Paulo")
        #expect(saoPaulo?.region == "America")
    }

    @Test func searchMatchesCityAndIdentifierLoosely() {
        let saoPaulo = TimeZoneCatalog.Entry(id: "America/Sao_Paulo", city: "Sao Paulo",
                                             region: "America", offsetSeconds: -3 * 3600)
        #expect(TimeZoneCatalog.matches(saoPaulo, query: "sao"))
        #expect(TimeZoneCatalog.matches(saoPaulo, query: "São"))
        #expect(TimeZoneCatalog.matches(saoPaulo, query: "america/sao"))
        #expect(!TimeZoneCatalog.matches(saoPaulo, query: "tokyo"))
        #expect(TimeZoneCatalog.matches(saoPaulo, query: "  ")) // blank shows all
    }

    @Test func incrementalTypingKeepsNarrowingToTheTarget() {
        // Each successive keystroke of "new y" must keep New York matched, so the
        // search field can filter live as the user types without ever dropping it.
        let newYork = TimeZoneCatalog.Entry(id: "America/New_York", city: "New York",
                                            region: "America", offsetSeconds: -4 * 3600)
        for prefix in ["n", "ne", "new", "new ", "new y", "new york"] {
            #expect(TimeZoneCatalog.matches(newYork, query: prefix),
                    "expected New York to match while typing \"\(prefix)\"")
        }
        #expect(!TimeZoneCatalog.matches(newYork, query: "new z"))
    }

    @Test func universalZonesUseTheirOwnStableGroup() {
        let universal = entries.filter { $0.id == "UTC" || $0.id.hasPrefix("Etc/") }
        #expect(!universal.isEmpty)
        #expect(universal.allSatisfy { $0.region == TimeZoneCatalog.universalRegion })
        #expect(TimeZoneCatalog.regionOrder.last == TimeZoneCatalog.universalRegion)
    }
}

import Foundation
import Testing
@testable import MeantimeKit

@Suite struct TimeZoneCatalogTests {
    let entries = TimeZoneCatalog.entries()

    @Test func dropsNonPlaceZones() {
        #expect(!entries.contains { $0.id.hasPrefix("Etc/") })
        #expect(!entries.contains { $0.id == "UTC" || $0.id == "GMT" })
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
}

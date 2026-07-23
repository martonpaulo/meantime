import SwiftUI
import MeantimeKit

/// The Add Clock sheet: a proper search field over every place-bearing time
/// zone, grouped by region, each row showing its flag, city, and live GMT
/// offset. Selecting a row adds the clock.
struct TimeZonePickerView: View {
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    @State private var query = ""
    @State private var entries: [TimeZoneCatalog.Entry] = []
    @FocusState private var searchFocused: Bool

    private var filtered: [TimeZoneCatalog.Entry] {
        entries.filter { TimeZoneCatalog.matches($0, query: query) }
    }

    /// Regions in canonical order, only those with matches.
    private var sections: [(region: String, entries: [TimeZoneCatalog.Entry])] {
        let grouped = Dictionary(grouping: filtered, by: \.region)
        return TimeZoneCatalog.regionOrder.compactMap { region in
            guard let matches = grouped[region], !matches.isEmpty else { return nil }
            return (region, matches)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            Divider()
            if filtered.isEmpty {
                emptyState
            } else {
                zoneList
            }
        }
        .frame(width: 440, height: 500)
        .onAppear {
            entries = TimeZoneCatalog.entries()
            searchFocused = true
        }
        .background {
            // ⌘W dismisses like any transient window (Escape is on Cancel).
            Button("", action: onCancel)
                .keyboardShortcut("w", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    private var header: some View {
        HStack {
            Text("Add Clock").font(.headline)
            Spacer()
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
        }
        .padding(Token.Space.lg)
    }

    private var searchField: some View {
        HStack(spacing: Token.Space.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Token.Color.secondaryText)
            TextField("Search for a city or time zone", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
        }
        .padding(.vertical, Token.Space.sm)
        .padding(.horizontal, Token.Space.md)
        .background(Token.Color.rowHighlight, in: RoundedRectangle(cornerRadius: Token.Radius.sm))
        .padding(.horizontal, Token.Space.lg)
        .padding(.bottom, Token.Space.md)
    }

    private var emptyState: some View {
        VStack(spacing: Token.Space.xs) {
            Spacer()
            Image(systemName: "globe")
                .font(.title2)
                .foregroundStyle(Token.Color.secondaryText)
            Text("No matching places")
                .foregroundStyle(Token.Color.secondaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var zoneList: some View {
        List {
            ForEach(sections, id: \.region) { section in
                Section(section.region) {
                    ForEach(section.entries) { entry in
                        ZoneRow(entry: entry) { onSelect(entry.id) }
                    }
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }
}

/// One selectable place: flag, city, and current GMT offset.
private struct ZoneRow: View {
    let entry: TimeZoneCatalog.Entry
    let select: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: Token.Space.md) {
                Text(RegionFlag.emoji(for: entry.id))
                Text(entry.city)
                    .foregroundStyle(Token.Color.primaryText)
                Spacer()
                Text(ZoneOffset.caption(offsetSeconds: entry.offsetSeconds))
                    .font(Token.Font.secondary.monospacedDigit())
                    .foregroundStyle(Token.Color.secondaryText)
            }
            .padding(.vertical, Token.Space.xs)
            .padding(.horizontal, Token.Space.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: Token.Radius.sm)
                .fill(isHovering ? Token.Color.rowHighlight : .clear)
        )
        .onHover { isHovering = $0 }
        .accessibilityLabel("\(entry.city), \(entry.region)")
    }
}

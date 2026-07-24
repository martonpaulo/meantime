import SwiftUI
import MeantimeKit

/// The first stage of Add Clock, embedded in the Clocks settings pane. Search
/// covers every place-bearing time zone and selecting one opens its draft.
struct TimeZonePickerView: View {
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    @State private var query = ""
    @State private var entries: [TimeZoneCatalog.Entry] = []

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
            Divider()
            if filtered.isEmpty {
                emptyState
            } else {
                zoneList
            }
        }
        .onAppear {
            entries = TimeZoneCatalog.entries()
        }
    }

    /// A top-left back control, matching the clock editor, so every step of the Add flow
    /// (list -> picker -> editor) returns to the previous one from the same place.
    private var header: some View {
        VStack(alignment: .leading, spacing: Token.Space.sm) {
            HStack {
                Button(action: onCancel) {
                    Label("Clocks", systemImage: "chevron.left")
                }
                .buttonStyle(.link)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Back to Clocks")
                Spacer()
            }
            Text("Choose a Time Zone").font(.headline)
            SearchField(text: $query, prompt: "City, time zone, or abbreviation")
        }
        .padding(Token.Space.lg)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Matching Time Zones", systemImage: "globe")
        } description: {
            Text("Try a city, IANA identifier, GMT offset, or abbreviation.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .scrollIndicators(.hidden)
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

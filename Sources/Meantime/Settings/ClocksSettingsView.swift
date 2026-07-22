import SwiftUI
import MeantimeKit

/// Manage the clock list: add, remove, reorder, and edit the selected clock.
struct ClocksSettingsView: View {
    @Environment(Preferences.self) private var preferences
    let formatter: ClockFormatter

    @State private var selection: WorldClock.ID?
    @State private var isAdding = false

    var body: some View {
        @Bindable var prefs = preferences
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(prefs.clocks) { clock in
                    ClockListRow(clock: clock).tag(clock.id)
                }
                .onMove { prefs.moveClocks(from: $0, to: $1) }
                .onDelete { prefs.removeClocks(at: $0) }
            }

            Divider()
            HStack(spacing: Token.Space.sm) {
                Button { isAdding = true } label: { Label("Add Clock", systemImage: "plus") }
                Button(role: .destructive) {
                    if let id = selection { preferences.removeClock(id: id); selection = nil }
                } label: { Label("Remove", systemImage: "minus") }
                    .disabled(selection == nil)
                Spacer()
            }
            .padding(Token.Space.sm)

            if let id = selection, let binding = clockBinding(for: id) {
                Divider()
                ClockEditorView(clock: binding, formatter: formatter)
                    .padding(Token.Space.md)
            }
        }
        .sheet(isPresented: $isAdding) {
            TimeZonePickerView { identifier in
                let clock = WorldClock(timeZoneID: identifier)
                preferences.addClock(clock)
                selection = clock.id
                isAdding = false
            } onCancel: {
                isAdding = false
            }
        }
    }

    /// A read/write binding into the stored clock with `id`, so edits persist
    /// through `Preferences` without the view owning any state.
    private func clockBinding(for id: WorldClock.ID) -> Binding<WorldClock>? {
        guard preferences.clocks.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { preferences.clocks.first(where: { $0.id == id })
                ?? WorldClock(timeZoneID: TimeZone.current.identifier) },
            set: { newValue in
                if let index = preferences.clocks.firstIndex(where: { $0.id == id }) {
                    preferences.clocks[index] = newValue
                }
            }
        )
    }
}

/// One row in the clock list: emoji, name, zone, and a panel-only indicator.
private struct ClockListRow: View {
    let clock: WorldClock

    var body: some View {
        HStack(spacing: Token.Space.sm) {
            Text(clock.displayEmoji)
            VStack(alignment: .leading, spacing: 0) {
                Text(clock.displayLabel)
                Text(clock.timeZoneID)
                    .font(Token.Font.secondary)
                    .foregroundStyle(Token.Color.secondaryText)
            }
            Spacer()
            if !clock.isPinned {
                Image(systemName: "eye.slash")
                    .foregroundStyle(Token.Color.secondaryText)
                    .help("Shown in the panel only")
            }
        }
        .padding(.vertical, Token.Space.xxs)
    }
}

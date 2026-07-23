import SwiftUI
import MeantimeKit

/// Manage the clock list: layout choice, reorder, per-row menu-bar toggle, and
/// a sheet editor for everything else. Views mutate `Preferences` directly,
/// which persists and updates the menu bar live.
struct ClocksPane: View {
    @Environment(Preferences.self) private var preferences
    let formatter: ClockFormatter

    @State private var editingClockID: WorldClock.ID?
    @State private var isAdding = false

    var body: some View {
        @Bindable var prefs = preferences
        Form {
            Section {
                Picker("Menu bar shows", selection: $prefs.menuBarLayout) {
                    Text("One item per clock").tag(MenuBarLayout.individual)
                    Text("All clocks in one item").tag(MenuBarLayout.combined)
                }
                .pickerStyle(.radioGroup)
            } footer: {
                Text("Clocks can also live in the dropdown only — turn off “In menu bar” for a clock below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(prefs.clocks) { clock in
                    ClockRow(clock: clock,
                             onEdit: { editingClockID = clock.id },
                             onRemove: { preferences.removeClock(id: clock.id) })
                }
                .onMove { prefs.moveClocks(from: $0, to: $1) }
                .onDelete { prefs.removeClocks(at: $0) }

                Button {
                    isAdding = true
                } label: {
                    Label("Add Clock…", systemImage: "plus")
                }
            } header: {
                Text("Clocks")
            } footer: {
                Text("Drag to reorder. The order here is the menu bar and dropdown order.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: Token.Size.paneWidth)
        .fixedSize()
        .sheet(isPresented: $isAdding) {
            TimeZonePickerView { identifier in
                let clock = WorldClock(timeZoneID: identifier)
                preferences.addClock(clock)
                isAdding = false
                editingClockID = clock.id
            } onCancel: {
                isAdding = false
            }
        }
        .sheet(item: editingBinding) { clock in
            ClockEditorSheet(clock: clockBinding(for: clock.id), formatter: formatter) {
                editingClockID = nil
            }
        }
    }

    /// Sheet identity for the editor: resolves the id to the live clock value.
    private var editingBinding: Binding<WorldClock?> {
        Binding(
            get: {
                guard let id = editingClockID else { return nil }
                return preferences.clocks.first { $0.id == id }
            },
            set: { newValue in
                if newValue == nil { editingClockID = nil }
            }
        )
    }

    /// A read/write binding into the stored clock, so edits persist through
    /// `Preferences` without the sheet owning any copy.
    private func clockBinding(for id: WorldClock.ID) -> Binding<WorldClock> {
        Binding(
            get: {
                preferences.clocks.first { $0.id == id }
                    ?? WorldClock(timeZoneID: TimeZone.current.identifier)
            },
            set: { preferences.update($0) }
        )
    }
}

/// One row: identity on the left, live schedule state, menu-bar toggle, edit.
private struct ClockRow: View {
    @Environment(Preferences.self) private var preferences
    let clock: WorldClock
    let onEdit: () -> Void
    let onRemove: () -> Void

    private var pinnedBinding: Binding<Bool> {
        Binding(
            get: { clock.isPinned },
            set: { newValue in
                var updated = clock
                updated.isPinned = newValue
                preferences.update(updated)
            }
        )
    }

    private var scheduleCaption: String? {
        guard clock.isPinned, !clock.activeWindows.isEmpty else { return nil }
        return clock.isActiveInMenuBar(at: Date())
            ? String(localized: "Scheduled · visible now")
            : String(localized: "Scheduled · hidden now")
    }

    var body: some View {
        HStack(spacing: Token.Space.md) {
            Text(clock.displayEmoji)
            VStack(alignment: .leading, spacing: 0) {
                Text(clock.displayLabel)
                Text(scheduleCaption.map { "\(clock.timeZoneID) · \($0)" } ?? clock.timeZoneID)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ReorderButtons(clockID: clock.id)
            Toggle("In menu bar", isOn: pinnedBinding)
                .toggleStyle(.checkbox)
            Button("Edit…", action: onEdit)
        }
        .padding(.vertical, Token.Space.xxs)
        .contextMenu {
            Button("Edit…", action: onEdit)
            Button("Remove", role: .destructive, action: onRemove)
        }
    }
}

/// Explicit move-up/move-down controls (drag still works; these are the
/// discoverable, accessible path).
private struct ReorderButtons: View {
    @Environment(Preferences.self) private var preferences
    let clockID: WorldClock.ID

    private var index: Int? {
        preferences.clocks.firstIndex { $0.id == clockID }
    }

    var body: some View {
        HStack(spacing: Token.Space.xxs) {
            Button {
                preferences.moveClock(id: clockID, by: -1)
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(index == 0)
            .accessibilityLabel("Move up")

            Button {
                preferences.moveClock(id: clockID, by: 1)
            } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(index == preferences.clocks.count - 1)
            .accessibilityLabel("Move down")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
    }
}

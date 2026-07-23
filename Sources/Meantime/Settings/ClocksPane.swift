import SwiftUI
import MeantimeKit

/// Manage the clock list. Field edits happen in a Save-gated sheet; list-level
/// commands such as add, remove, and reorder remain direct actions.
struct ClocksPane: View {
    @Environment(Preferences.self) private var preferences
    @Environment(SettingsPreview.self) private var settingsPreview
    @State private var editingClockID: WorldClock.ID?
    @State private var isAdding = false

    var body: some View {
        Form {
            Section {
                ForEach(preferences.clocks) { clock in
                    ClockRow(clock: clock,
                             onEdit: { editingClockID = clock.id },
                             onRemove: { preferences.removeClock(id: clock.id) })
                }
                .onMove { preferences.moveClocks(from: $0, to: $1) }
                .onDelete { preferences.removeClocks(at: $0) }

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
        .sheet(item: editingBinding, onDismiss: settingsPreview.discardClock) { clock in
            ClockEditorSheet(
                clock: clock,
                onPreview: settingsPreview.preview,
                onSave: { updated in
                    settingsPreview.saveClock(updated)
                    editingClockID = nil
                },
                onCancel: {
                    settingsPreview.discardClock()
                    editingClockID = nil
                })
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

}

/// One row: identity, saved visibility state, reorder, and Save-gated editing.
private struct ClockRow: View {
    let clock: WorldClock
    let onEdit: () -> Void
    let onRemove: () -> Void

    private var scheduleCaption: String? {
        guard clock.isPinned, !clock.activeWindows.isEmpty else { return nil }
        return clock.isActiveInMenuBar(at: Date())
            ? String(localized: "Scheduled · visible now")
            : String(localized: "Scheduled · hidden now")
    }

    var body: some View {
        HStack(spacing: Token.Space.md) {
            if let adornment = clock.displayAdornment {
                Text(adornment)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(clock.displayLabel)
                Text(scheduleCaption.map { "\(clock.timeZoneID) · \($0)" } ?? clock.timeZoneID)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ReorderButtons(clockID: clock.id)
            Label(clock.isPinned ? "In Menu Bar" : "Dropdown Only",
                  systemImage: clock.isPinned ? "menubar.rectangle" : "rectangle.bottomthird.inset.filled")
                .font(.callout)
                .foregroundStyle(.secondary)
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

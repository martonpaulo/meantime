import SwiftUI
import MeantimeKit

/// Manage the clock list. Field edits happen in a Save-gated sheet; destructive
/// removal is explicit and confirmed, while add and reorder remain direct.
struct ClocksPane: View {
    @Environment(Preferences.self) private var preferences
    @Environment(SettingsPreview.self) private var settingsPreview
    @State private var editingClockID: WorldClock.ID?
    @State private var clocksPendingRemoval: [WorldClock] = []
    @State private var isAdding = false

    var body: some View {
        Form {
            Section {
                ForEach(preferences.clocks) { clock in
                    ClockRow(clock: clock,
                             onEdit: { editingClockID = clock.id },
                             onRemove: { clocksPendingRemoval = [clock] })
                }
                .onMove { preferences.moveClocks(from: $0, to: $1) }
                .onDelete { offsets in
                    clocksPendingRemoval = offsets.compactMap { index in
                        preferences.clocks.indices.contains(index)
                            ? preferences.clocks[index]
                            : nil
                    }
                }

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
        .alert(removalTitle, isPresented: removalConfirmationPresented) {
            Button(removalActionTitle, role: .destructive, action: removePendingClocks)
            Button("Cancel", role: .cancel) { clocksPendingRemoval = [] }
        } message: {
            Text(removalMessage)
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

    private var removalConfirmationPresented: Binding<Bool> {
        Binding(
            get: { !clocksPendingRemoval.isEmpty },
            set: { isPresented in
                if !isPresented { clocksPendingRemoval = [] }
            }
        )
    }

    private var removalTitle: String {
        guard clocksPendingRemoval.count == 1,
              let clock = clocksPendingRemoval.first else {
            return "Remove \(clocksPendingRemoval.count) clocks?"
        }
        return "Remove “\(clock.displayLabel)”?"
    }

    private var removalActionTitle: String {
        clocksPendingRemoval.count == 1 ? "Remove Clock" : "Remove Clocks"
    }

    private var removalMessage: String {
        clocksPendingRemoval.count == 1
            ? "This removes the clock from the menu bar and dropdown. This can’t be undone."
            : "These clocks will be removed from the menu bar and dropdown. This can’t be undone."
    }

    private func removePendingClocks() {
        let ids = Set(clocksPendingRemoval.map(\.id))
        preferences.removeClocks(ids: ids)
        clocksPendingRemoval = []
    }
}

/// One row: identity, saved visibility state, reorder, and Save-gated editing.
private struct ClockRow: View {
    let clock: WorldClock
    let onEdit: () -> Void
    let onRemove: () -> Void

    private var detailCaption: String {
        guard clock.isPinned, !clock.activeWindows.isEmpty else {
            return clock.timeZoneID
        }
        return "\(clock.timeZoneID) · \(String(localized: "Scheduled"))"
    }

    var body: some View {
        HStack(spacing: Token.Space.md) {
            if let adornment = clock.displayAdornment {
                Text(adornment)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(clock.displayLabel)
                Text(detailCaption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ReorderButtons(clockID: clock.id)
            Label(clock.isPinned ? "Menu Bar" : "Dropdown Only",
                  systemImage: clock.isPinned ? "menubar.rectangle" : "rectangle.bottomthird.inset.filled")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Edit…", action: onEdit)
            Button(role: .destructive, action: onRemove) {
                Label("Remove \(clock.displayLabel)", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("Remove \(clock.displayLabel)…")
            .accessibilityLabel("Remove \(clock.displayLabel)")
        }
        .padding(.vertical, Token.Space.xxs)
        .contextMenu {
            Button("Edit…", action: onEdit)
            Button("Remove Clock…", role: .destructive, action: onRemove)
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

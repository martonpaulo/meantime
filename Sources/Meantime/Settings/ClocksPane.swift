import SwiftUI
import MeantimeKit

/// A selection-first native list. Row actions live in the footer and context
/// menu, keeping long labels and accessibility sizes from fighting controls.
struct ClocksPane: View {
    @Environment(Preferences.self) private var preferences
    @Environment(ClockEditingSession.self) private var editingSession

    let formatter: ClockFormatter

    @State private var selectedIDs = Set<WorldClock.ID>()
    @State private var clocksPendingRemoval: [WorldClock] = []

    private var selectedClocks: [WorldClock] {
        preferences.clocks.filter { selectedIDs.contains($0.id) }
    }

    private var singleSelection: WorldClock? {
        selectedClocks.count == 1 ? selectedClocks[0] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            switch editingSession.destination {
            case .list:
                listContent
                Divider()
                actionBar
            case .picker:
                TimeZonePickerView { identifier in
                    editingSession.beginAdding(timeZoneID: identifier)
                } onCancel: {
                    editingSession.requestExit(to: .list)
                }
            case .editor:
                ClockEditorView(formatter: formatter)
            }
        }
        .frame(width: Token.Size.paneWidth, height: Token.Size.paneHeight)
        .alert(removalTitle, isPresented: removalConfirmationPresented) {
            Button(removalActionTitle, role: .destructive, action: removePendingClocks)
            Button("Cancel", role: .cancel) { clocksPendingRemoval = [] }
        } message: {
            Text(removalMessage)
        }
        .onChange(of: preferences.clocks) { _, clocks in
            selectedIDs.formIntersection(Set(clocks.map(\.id)))
        }
        .background {
            Group {
                Button("", action: editSelection)
                    .keyboardShortcut(.return, modifiers: [])
                Button("", action: requestRemoval)
                    .keyboardShortcut(.delete, modifiers: [])
            }
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var listContent: some View {
        if preferences.clocks.isEmpty {
            ContentUnavailableView {
                Label("No clocks", systemImage: "clock.badge.questionmark")
            } description: {
                Text("Add a time zone to see its local time in the menu bar and panel.")
            } actions: {
                Button("Add Clock…") { presentAdd() }
                    .keyboardShortcut(.defaultAction)
            }
        } else {
            clockList
        }
    }

    private var clockList: some View {
        List(selection: $selectedIDs) {
            ForEach(preferences.clocks) { clock in
                ClockListRow(clock: clock)
                    .tag(clock.id)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        selectedIDs = [clock.id]
                        editingSession.beginEditing(clock)
                    }
                    .contextMenu {
                        Button("Edit…") {
                            selectedIDs = [clock.id]
                            editingSession.beginEditing(clock)
                        }
                        Divider()
                        Button("Move Up") {
                            preferences.moveClock(id: clock.id, by: -1)
                        }
                        .disabled(preferences.clocks.first?.id == clock.id)
                        Button("Move Down") {
                            preferences.moveClock(id: clock.id, by: 1)
                        }
                        .disabled(preferences.clocks.last?.id == clock.id)
                        Divider()
                        Button("Remove Clock…", role: .destructive) {
                            clocksPendingRemoval = [clock]
                        }
                    }
            }
            .onMove { preferences.moveClocks(from: $0, to: $1) }
        }
        .listStyle(.inset)
        .scrollIndicators(.hidden)
        .accessibilityLabel("Clocks")
        .onAppear {
            if selectedIDs.isEmpty, let first = preferences.clocks.first {
                selectedIDs = [first.id]
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: Token.Space.sm) {
            ControlGroup {
                Button(action: presentAdd) {
                    Label("Add Clock", systemImage: "plus")
                }
                Button(action: requestRemoval) {
                    Label("Remove Selected Clocks", systemImage: "minus")
                }
                .disabled(selectedIDs.isEmpty)
            }
            .labelStyle(.iconOnly)

            ControlGroup {
                Button {
                    moveSelection(by: -1)
                } label: {
                    Label("Move Up", systemImage: "chevron.up")
                }
                .disabled(!canMoveSelection(by: -1))

                Button {
                    moveSelection(by: 1)
                } label: {
                    Label("Move Down", systemImage: "chevron.down")
                }
                .disabled(!canMoveSelection(by: 1))
            }
            .labelStyle(.iconOnly)

            Text("\(preferences.clocks.count) \(preferences.clocks.count == 1 ? "clock" : "clocks")")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Edit…", action: editSelection)
                .disabled(singleSelection == nil)
        }
        .padding(Token.Space.md)
    }

    private var removalConfirmationPresented: Binding<Bool> {
        Binding(
            get: { !clocksPendingRemoval.isEmpty },
            set: { if !$0 { clocksPendingRemoval = [] } })
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
            ? "This removes the clock from the menu bar and panel. This action can’t be undone."
            : "These clocks will be removed from the menu bar and panel. This action can’t be undone."
    }

    private func presentAdd() {
        editingSession.showPicker()
    }

    private func editSelection() {
        guard let singleSelection else { return }
        editingSession.beginEditing(singleSelection)
    }

    private func requestRemoval() {
        clocksPendingRemoval = selectedClocks
    }

    private func removePendingClocks() {
        let ids = Set(clocksPendingRemoval.map(\.id))
        preferences.removeClocks(ids: ids)
        selectedIDs.subtract(ids)
        clocksPendingRemoval = []
    }

    private func canMoveSelection(by offset: Int) -> Bool {
        guard let clock = singleSelection,
              let index = preferences.clocks.firstIndex(where: { $0.id == clock.id }) else {
            return false
        }
        return preferences.clocks.indices.contains(index + offset)
    }

    private func moveSelection(by offset: Int) {
        guard let clock = singleSelection else { return }
        preferences.moveClock(id: clock.id, by: offset)
    }
}

private struct ClockListRow: View {
    let clock: WorldClock

    private var detail: String {
        guard clock.isPinned else { return "\(clock.timeZoneID) · Panel only" }
        guard !clock.activeWindows.isEmpty else { return clock.timeZoneID }
        return "\(clock.timeZoneID) · Scheduled"
    }

    var body: some View {
        LabeledContent {
            Image(systemName: clock.isPinned ? "menubar.rectangle" : "rectangle.bottomthird.inset.filled")
                .foregroundStyle(.secondary)
                .help(clock.isPinned ? "Shown in menu bar" : "Panel only")
        } label: {
            HStack(spacing: Token.Space.md) {
                Text(clock.displayAdornment ?? "")
                    .frame(width: Token.Size.adornmentColumn)
                VStack(alignment: .leading, spacing: Token.Space.xxxs) {
                    Text(clock.displayLabel)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(.vertical, Token.Space.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(clock.displayLabel), \(detail), \(clock.isPinned ? "shown in menu bar" : "panel only")")
    }
}

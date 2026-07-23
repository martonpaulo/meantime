import SwiftUI
import MeantimeKit

/// Edits one clock as a transient draft. Every change previews in the real
/// status item; only Save updates typed preferences.
struct ClockEditorSheet: View {
    private let original: WorldClock
    let onPreview: (WorldClock) -> Void
    let onSave: (WorldClock) -> Void
    let onCancel: () -> Void

    @State private var draft: WorldClock
    @State private var unsavedConfirmationShown = false
    @State private var restoreConfirmationShown = false

    init(clock: WorldClock,
         onPreview: @escaping (WorldClock) -> Void,
         onSave: @escaping (WorldClock) -> Void,
         onCancel: @escaping () -> Void) {
        original = clock
        self.onPreview = onPreview
        self.onSave = onSave
        self.onCancel = onCancel
        _draft = State(initialValue: clock)
    }

    private var hasChanges: Bool { draft != original }

    private var isValid: Bool {
        switch draft.adornmentStyle {
        case .emoji:
            draft.customEmoji?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .text:
            draft.customText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .flag, .none:
            true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            editorForm
            actions
        }
        .frame(width: Token.Size.editorWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { onPreview(draft) }
        .onChange(of: draft) { _, value in onPreview(value) }
        .interactiveDismissDisabled(hasChanges)
        .confirmationDialog("Save changes to this clock?",
                            isPresented: $unsavedConfirmationShown) {
            if isValid {
                Button("Save Changes") { save() }
            }
            Button("Discard Changes", role: .destructive) { onCancel() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your menu-bar preview has unsaved changes.")
        }
        .confirmationDialog("Restore this clock to its defaults?",
                            isPresented: $restoreConfirmationShown) {
            Button("Restore Defaults", role: .destructive) {
                draft = draft.restoredToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The time zone stays the same. Label, leading item, menu-bar style, visibility, and scheduled hours return to their defaults after you save.")
        }
        .background {
            Group {
                Button("", action: requestDismiss)
                    .keyboardShortcut("w", modifiers: .command)
                Button("", action: requestDismiss)
                    .keyboardShortcut(.cancelAction)
            }
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    private var header: some View {
        HStack(spacing: Token.Space.sm) {
            if let adornment = draft.displayAdornment {
                Text(adornment)
                    .frame(minWidth: Token.Size.adornmentColumn)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(draft.displayLabel).font(.headline)
                Text(draft.timeZoneID)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(Token.Space.lg)
    }

    private var editorForm: some View {
        Form {
            Section {
                TextField("Label", text: $draft.customLabel.orEmpty(),
                          prompt: Text(CityLabel.name(for: draft.timeZoneID)))
                Picker("Leading item", selection: $draft.adornmentStyle) {
                    Text("Country Flag").tag(ClockAdornmentStyle.flag)
                    Text("Emoji").tag(ClockAdornmentStyle.emoji)
                    Text("Text").tag(ClockAdornmentStyle.text)
                    Text("None").tag(ClockAdornmentStyle.none)
                }

                if draft.adornmentStyle == .emoji {
                    TextField("Emoji", text: $draft.customEmoji.orEmpty(),
                              prompt: Text(verbatim: "🌍"))
                } else if draft.adornmentStyle == .text {
                    TextField("Text", text: $draft.customText.orEmpty(),
                              prompt: Text(verbatim: "NYC"))
                }

                if !isValid {
                    Text("Enter a value or choose Country Flag or None.")
                        .font(.callout)
                        .foregroundStyle(Token.Color.errorText)
                }
            } header: {
                Text("Identity")
            } footer: {
                Text("Country Flag is the default derived from this time zone. Emoji and text are kept separately when you switch styles.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Menu Bar") {
                Toggle("Show in menu bar", isOn: $draft.isPinned)
                Picker("Style", selection: $draft.renderMode) {
                    Text("Leading item and time").tag(ClockRenderMode.flagAndTime)
                    Text("Time only").tag(ClockRenderMode.timeOnly)
                    Text("Analog clock face").tag(ClockRenderMode.analogClock)
                }
                .pickerStyle(.radioGroup)
                .disabled(!draft.isPinned)
            }

            ScheduleSection(clock: $draft)

            Section {
                LabeledContent("Return this clock to its defaults") {
                    Button("Restore Defaults…", role: .destructive) {
                        restoreConfirmationShown = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    private var actions: some View {
        HStack(spacing: Token.Space.sm) {
            Button("Cancel", action: requestDismiss)
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Save", action: save)
                .keyboardShortcut(.defaultAction)
                .disabled(!hasChanges || !isValid)
        }
        .padding(Token.Space.lg)
    }

    private func save() {
        guard isValid else { return }
        onSave(draft)
    }

    private func requestDismiss() {
        if hasChanges {
            unsavedConfirmationShown = true
        } else {
            onCancel()
        }
    }
}

/// Scheduled menu-bar hours, expressed in the clock's own time zone.
private struct ScheduleSection: View {
    @Binding var clock: WorldClock

    private var scheduleEnabled: Binding<Bool> {
        Binding(
            get: { !clock.activeWindows.isEmpty },
            set: { enabled in
                if enabled, clock.activeWindows.isEmpty {
                    clock.activeWindows = [PreferenceDefaults.suggestedActiveWindow]
                } else if !enabled {
                    clock.activeWindows = []
                }
            }
        )
    }

    var body: some View {
        Section {
            Toggle("Only show at scheduled hours", isOn: scheduleEnabled)
                .disabled(!clock.isPinned)

            ForEach($clock.activeWindows) { $window in
                Grid(alignment: .center, horizontalSpacing: Token.Space.sm) {
                    GridRow {
                        DatePicker("From", selection: minuteBinding($window.startMinute),
                                   displayedComponents: [.hourAndMinute])
                            .datePickerStyle(.field)
                            .controlSize(.small)
                        DatePicker("To", selection: minuteBinding($window.endMinute),
                                   displayedComponents: [.hourAndMinute])
                            .datePickerStyle(.field)
                            .controlSize(.small)
                        Button {
                            clock.activeWindows.removeAll { $0.id == window.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove hours")
                    }
                }
            }

            if !clock.activeWindows.isEmpty {
                Button {
                    clock.activeWindows.append(PreferenceDefaults.suggestedActiveWindow)
                } label: {
                    Label("Add Hours", systemImage: "plus")
                }
            }
        } header: {
            Text("Schedule")
        } footer: {
            Text("Times are in this clock's own time zone. Outside these hours the clock leaves the menu bar but stays in the dropdown.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func minuteBinding(_ minute: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { ScheduleTime.date(fromMinute: minute.wrappedValue) },
            set: { minute.wrappedValue = ScheduleTime.minute(from: $0) }
        )
    }
}

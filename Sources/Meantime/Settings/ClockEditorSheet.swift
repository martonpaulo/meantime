import SwiftUI
import MeantimeKit

/// Save-gated creation and editing. The draft previews through
/// `SettingsPreview`, while typed preferences change exactly once on commit.
struct ClockEditorSheet: View {
    @Environment(Preferences.self) private var preferences
    @Environment(SettingsPreview.self) private var settingsPreview

    let formatter: ClockFormatter
    let onFinish: () -> Void
    let onBack: (() -> Void)?

    @State private var editDraft: ClockEditDraft
    @State private var unsavedConfirmationShown = false
    @State private var restoreConfirmationShown = false

    init(draft: ClockEditDraft, formatter: ClockFormatter,
         onFinish: @escaping () -> Void, onBack: (() -> Void)? = nil) {
        _editDraft = State(initialValue: draft)
        self.formatter = formatter
        self.onFinish = onFinish
        self.onBack = onBack
    }

    private var clock: WorldClock { editDraft.clock }
    private var issues: [ClockValidationIssue] { editDraft.validationIssues }
    private var actionTitle: String { editDraft.isNew ? "Add Clock" : "Save" }
    private var discardTitle: String {
        editDraft.isNew ? "Discard New Clock" : "Discard Changes"
    }

    var body: some View {
        VStack(spacing: 0) {
            EditorPreview(clock: clock, formatter: formatter)
            Divider()
            editorForm
            Divider()
            actions
        }
        .frame(width: Token.Size.editorWidth, height: Token.Size.editorHeight)
        .onAppear { settingsPreview.preview(clock: clock) }
        .onChange(of: editDraft.clock) { _, value in
            settingsPreview.preview(clock: value)
        }
        .interactiveDismissDisabled(editDraft.hasChanges)
        .confirmationDialog(
            editDraft.isNew ? "Add this clock?" : "Save changes to this clock?",
            isPresented: $unsavedConfirmationShown
        ) {
            if editDraft.canCommit {
                Button(actionTitle) { commit() }
            }
            Button(discardTitle, role: .destructive) { finishWithoutSaving() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The live preview contains changes that have not been saved.")
        }
        .confirmationDialog("Restore this clock to its defaults?",
                            isPresented: $restoreConfirmationShown) {
            Button("Restore Defaults", role: .destructive) {
                editDraft.clock = editDraft.clock.restoredToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its time zone stays the same. Name, leading item, menu-bar style, visibility, and scheduled hours return to their defaults after you save.")
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

    private var editorForm: some View {
        Form {
            identitySection
            menuBarSection
            ScheduleSection(clock: $editDraft.clock)

            Section {
                LabeledContent("Return this clock to its defaults") {
                    Button("Restore Defaults…", role: .destructive) {
                        restoreConfirmationShown = true
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var identitySection: some View {
        Section {
            TextField(
                "Name",
                text: limitedOptionalBinding(
                    \.customLabel, limit: UserInputPolicy.labelLimit),
                prompt: Text(CityLabel.name(for: clock.timeZoneID)))

            Picker("Leading item", selection: $editDraft.clock.adornmentStyle) {
                Text("Country Flag").tag(ClockAdornmentStyle.flag)
                Text("Emoji").tag(ClockAdornmentStyle.emoji)
                Text("Text").tag(ClockAdornmentStyle.text)
                Text("None").tag(ClockAdornmentStyle.none)
            }

            if clock.adornmentStyle == .emoji {
                TextField(
                    "Emoji",
                    text: limitedOptionalBinding(
                        \.customEmoji, limit: UserInputPolicy.emojiLimit),
                    prompt: Text(verbatim: "🌍"))
                if issues.contains(.emojiRequired) {
                    ValidationMessage("Choose one emoji.")
                }
            } else if clock.adornmentStyle == .text {
                TextField(
                    "Text",
                    text: limitedOptionalBinding(
                        \.customText, limit: UserInputPolicy.leadingTextLimit),
                    prompt: Text(verbatim: "NYC"))
                if issues.contains(.leadingTextRequired) {
                    ValidationMessage("Enter short text or choose another leading item.")
                }
            }
        } header: {
            Text("Identity")
        } footer: {
            Text("The country flag is derived from the time zone. Emoji and text stay saved when you switch styles.")
        }
    }

    private var menuBarSection: some View {
        Section {
            Toggle("Show in menu bar", isOn: $editDraft.clock.isPinned)
            Picker("Style", selection: $editDraft.clock.renderMode) {
                Text("Leading item and time").tag(ClockRenderMode.flagAndTime)
                Text("Time only").tag(ClockRenderMode.timeOnly)
                Text("Analog clock face").tag(ClockRenderMode.analogClock)
            }
            .pickerStyle(.radioGroup)
            .disabled(!clock.isPinned)

            if settingsPreview.menuBarLayout == .combined,
               clock.renderMode == .analogClock {
                Label(
                    "The combined menu-bar item shows this clock as leading item and time. Its analog style is kept for individual layout.",
                    systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Menu Bar")
        } footer: {
            if !clock.isPinned {
                Text("This clock remains visible in the dropdown.")
            }
        }
    }

    private var actions: some View {
        HStack(spacing: Token.Space.sm) {
            if let onBack {
                Button("Back", action: onBack)
            }
            Button("Cancel", action: requestDismiss)
                .keyboardShortcut(.cancelAction)
            Spacer()
            if editDraft.hasChanges {
                Text("Not saved")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Unsaved changes")
            }
            Button(actionTitle, action: commit)
                .keyboardShortcut(.defaultAction)
                .disabled(!editDraft.canCommit)
        }
        .padding(Token.Space.lg)
    }

    private func limitedOptionalBinding(
        _ keyPath: WritableKeyPath<WorldClock, String?>, limit: Int
    ) -> Binding<String> {
        Binding(
            get: { editDraft.clock[keyPath: keyPath] ?? "" },
            set: { value in
                let limited = UserInputPolicy.truncated(value, limit: limit)
                editDraft.clock[keyPath: keyPath] = limited.isEmpty ? nil : limited
            })
    }

    private func commit() {
        guard editDraft.commit(to: preferences) else { return }
        settingsPreview.discardClock()
        onFinish()
    }

    private func finishWithoutSaving() {
        settingsPreview.discardClock()
        onFinish()
    }

    private func requestDismiss() {
        if editDraft.hasChanges {
            unsavedConfirmationShown = true
        } else {
            finishWithoutSaving()
        }
    }
}

/// Always-visible preview for pinned, hidden, and scheduled clocks.
private struct EditorPreview: View {
    @Environment(SettingsPreview.self) private var settingsPreview
    let clock: WorldClock
    let formatter: ClockFormatter
    @ScaledMetric(relativeTo: .body) private var timeScale = 1.0

    private var time: String {
        formatter.string(for: Date(), clock: clock, format: settingsPreview.timeFormat)
    }

    private var status: String {
        if !clock.isPinned { return "Dropdown only" }
        if !clock.activeWindows.isEmpty { return "Scheduled menu-bar preview" }
        return settingsPreview.menuBarLayout == .combined
            ? "Combined menu-bar preview"
            : "Menu-bar preview"
    }

    private var usesTextFallback: Bool {
        settingsPreview.menuBarLayout == .combined && clock.renderMode == .analogClock
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: Token.Space.md,
             verticalSpacing: Token.Space.xxs) {
            GridRow {
                Text("Preview")
                    .font(.headline)
                    .gridCellColumns(2)
            }
            GridRow {
                previewContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Token.Space.lg)
        .background(Token.Color.previewBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status), \(clock.displayLabel), \(time)")
    }

    @ViewBuilder private var previewContent: some View {
        HStack(spacing: Token.Space.sm) {
            if clock.renderMode != .timeOnly,
               let adornment = clock.displayAdornment {
                Text(adornment)
            }
            VStack(alignment: .leading, spacing: Token.Space.xxxs) {
                Text(clock.displayLabel)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                if clock.renderMode == .analogClock && !usesTextFallback {
                    Label("Analog clock face", systemImage: "clock")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text(time)
                        .font(Token.Font.time(settingsPreview.textSize * timeScale))
                        .lineLimit(1)
                }
            }
        }
    }
}

/// Scheduled menu-bar hours in the clock's own time zone.
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
            })
    }

    private var scheduleIssues: [ScheduleValidationIssue] {
        ScheduleValidation.issues(in: clock.activeWindows)
    }

    private var suggestedWindow: ActiveWindow? {
        ScheduleSuggestion.nextWindow(existing: clock.activeWindows)
    }

    var body: some View {
        Section {
            Toggle("Only show at scheduled hours", isOn: scheduleEnabled)
                .disabled(!clock.isPinned)

            ForEach($clock.activeWindows) { $window in
                Grid(alignment: .center, horizontalSpacing: Token.Space.sm) {
                    GridRow {
                        DatePicker(
                            "From",
                            selection: minuteBinding($window.startMinute),
                            displayedComponents: [.hourAndMinute])
                            .datePickerStyle(.field)
                        DatePicker(
                            "To",
                            selection: minuteBinding($window.endMinute),
                            displayedComponents: [.hourAndMinute])
                            .datePickerStyle(.field)
                        Button {
                            clock.activeWindows.removeAll { $0.id == window.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(
                            "Remove hours from \(ScheduleTime.label(fromMinute: window.startMinute)) to \(ScheduleTime.label(fromMinute: window.endMinute))")
                    }
                }
            }

            if !scheduleIssues.isEmpty {
                ValidationMessage(
                    "Scheduled hours cannot have matching start and end times, repeat, or overlap.")
            }

            if !clock.activeWindows.isEmpty {
                Button {
                    if let suggestedWindow {
                        clock.activeWindows.append(suggestedWindow)
                    }
                } label: {
                    Label("Add Hours", systemImage: "plus")
                }
                .disabled(suggestedWindow == nil)
            }
        } header: {
            Text("Schedule")
        } footer: {
            Text("Times use this clock's own time zone. An end earlier than its start continues overnight. Outside these hours, the clock stays in the dropdown.")
        }
    }

    private func minuteBinding(_ minute: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { ScheduleTime.date(fromMinute: minute.wrappedValue) },
            set: { minute.wrappedValue = ScheduleTime.minute(from: $0) })
    }
}

private struct ValidationMessage: View {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        Label(message, systemImage: "exclamationmark.circle")
            .font(.callout)
            .foregroundStyle(Token.Color.errorText)
            .accessibilityLabel("Error: \(message)")
    }
}

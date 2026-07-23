import SwiftUI
import MeantimeKit

/// Save-gated creation and editing inside the Clocks settings pane. The draft
/// previews through `SettingsPreview`; preferences change only on Save.
struct ClockEditorView: View {
    @Environment(SettingsPreview.self) private var settingsPreview
    @Environment(ClockEditingSession.self) private var editingSession

    let formatter: ClockFormatter

    @State private var restoreConfirmationShown = false

    // `body` renders `editorContent` only while the session holds a draft; the fallback
    // keeps this non-optional (so the form's bindings stay simple) and is never reached
    // on screen. It replaces a force-unwrap that could crash if the draft cleared while a
    // confirmation dialog was still dismissing.
    private var editDraft: ClockEditDraft {
        editingSession.draft ?? ClockEditDraft(existing: WorldClock(timeZoneID: "UTC"))
    }
    private var clock: WorldClock { editDraft.clock }
    private var issues: [ClockValidationIssue] { editDraft.validationIssues }
    private var actionTitle: String { editDraft.isNew ? "Add Clock" : "Save" }
    private var discardTitle: String {
        editDraft.isNew ? "Discard New Clock" : "Discard Changes"
    }

    @ViewBuilder
    var body: some View {
        if editingSession.draft != nil {
            editorContent
        }
    }

    private var editorContent: some View {
        VStack(spacing: 0) {
            EditorPreview(clock: clock, formatter: formatter)
            Divider()
            editorForm
            Divider()
            actions
        }
        .confirmationDialog(
            editDraft.isNew ? "Add this clock before leaving?" : "Save changes to this clock?",
            isPresented: pendingExitPresented
        ) {
            if editDraft.canCommit {
                Button(actionTitle) { commit() }
            }
            Button(discardTitle, role: .destructive) {
                editingSession.discardPendingExit()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Changes are visible in the menu bar until you save or discard them.")
        }
        .confirmationDialog("Restore this clock to its defaults?",
                            isPresented: $restoreConfirmationShown) {
            Button("Restore Defaults", role: .destructive) {
                editingSession.restoreDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The time zone stays the same. Name, leading item, menu bar style, visibility, and scheduled hours reset after you save.")
        }
        .background {
            Group {
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
            ScheduleSection(clock: fullClockBinding)

            Section {
                LabeledContent("Return this clock to its defaults") {
                    Button("Restore Defaults…", role: .destructive) {
                        restoreConfirmationShown = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollIndicators(.hidden)
    }

    private var identitySection: some View {
        Section {
            TextField(
                "Name",
                text: limitedOptionalBinding(
                    \.customLabel, limit: UserInputPolicy.labelLimit),
                prompt: Text(CityLabel.name(for: clock.timeZoneID)))

            Picker("Leading item", selection: clockBinding(\.adornmentStyle)) {
                Text("Country flag").tag(ClockAdornmentStyle.flag)
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
            Text("Display")
        } footer: {
            Text("The country flag comes from the time zone. Custom emoji and text remain saved when you switch leading items.")
        }
    }

    private var menuBarSection: some View {
        Section {
            Toggle("Show in menu bar", isOn: clockBinding(\.isPinned))
            Picker("Style", selection: clockBinding(\.renderMode)) {
                Text("Leading item and time").tag(ClockRenderMode.flagAndTime)
                Text("Time only").tag(ClockRenderMode.timeOnly)
                Text("Analog clock face").tag(ClockRenderMode.analogClock)
            }
            .pickerStyle(.radioGroup)
            .disabled(!clock.isPinned)

            if settingsPreview.menuBarLayout == .combined,
               clock.renderMode == .analogClock {
                Label(
                    "Combined layout shows this clock as a leading item and time. The analog face remains available in individual layout.",
                    systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Menu Bar")
        } footer: {
            if !clock.isPinned {
                Text("This clock remains visible in the panel.")
            }
        }
    }

    private var actions: some View {
        HStack(spacing: Token.Space.sm) {
            if editDraft.isNew {
                Button("Back") { editingSession.requestExit(to: .picker) }
            }
            Button("Cancel", action: requestDismiss)
                .keyboardShortcut(.cancelAction)
            Spacer()
            if editDraft.hasChanges {
                UnsavedBadge()
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
                var updated = clock
                updated[keyPath: keyPath] = limited.isEmpty ? nil : limited
                editingSession.updateClock(updated)
            })
    }

    private func clockBinding<Value>(
        _ keyPath: WritableKeyPath<WorldClock, Value>
    ) -> Binding<Value> {
        Binding(
            get: { clock[keyPath: keyPath] },
            set: { value in
                var updated = clock
                updated[keyPath: keyPath] = value
                editingSession.updateClock(updated)
            })
    }

    private var fullClockBinding: Binding<WorldClock> {
        Binding(
            get: { clock },
            set: { value in editingSession.updateClock(value) })
    }

    private var pendingExitPresented: Binding<Bool> {
        Binding(
            get: { editingSession.pendingExit != nil },
            set: { if !$0 { editingSession.cancelPendingExit() } })
    }

    private func commit() {
        _ = editingSession.save()
    }

    private func requestDismiss() {
        editingSession.requestExit(to: .list)
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
        if !clock.isPinned { return "Panel only" }
        if !clock.activeWindows.isEmpty { return "Scheduled menu bar" }
        return settingsPreview.menuBarLayout == .combined
            ? "Combined menu bar"
            : "Menu bar"
    }

    private var usesTextFallback: Bool {
        settingsPreview.menuBarLayout == .combined && clock.renderMode == .analogClock
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: Token.Space.md,
             verticalSpacing: Token.Space.sm) {
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
                        scheduleField("From", date: minuteBinding($window.startMinute))
                        scheduleField("To", date: minuteBinding($window.endMinute))
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
            Text("Times use this clock's own time zone. If an end time is earlier than its start, the schedule continues overnight. Outside these hours, the clock stays in the panel.")
        }
    }

    /// A labeled hour-and-minute field for one schedule edge. Fixed to the schedule's
    /// stable zone so "5 PM" typed here is stored (and read at runtime) as 5 PM in the
    /// clock's own zone, never shifted by the editor's local GMT offset.
    private func scheduleField(_ title: String, date: Binding<Date>) -> some View {
        HStack(spacing: Token.Space.xs) {
            Text(title).foregroundStyle(.secondary)
            TimeField(date: date, timeZone: ScheduleTime.zone,
                      controlSize: .small, accessibilityLabel: title)
                .fixedSize()
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

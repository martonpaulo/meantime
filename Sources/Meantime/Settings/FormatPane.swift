import SwiftUI
import MeantimeKit

/// Preset-first time formatting and menu-bar appearance. Changes preview in
/// the real status item and persist together only after Save.
struct FormatPane: View {
    @Environment(Preferences.self) private var preferences
    @Environment(SettingsPreview.self) private var settingsPreview
    let formatter: ClockFormatter

    @State private var discardConfirmationShown = false
    @FocusState private var patternFieldFocused: Bool

    private var draft: SettingsPreview.AppearanceDraft {
        settingsPreview.appearanceDraft
            ?? SettingsPreview.AppearanceDraft(preferences: preferences)
    }

    private var previewText: String {
        let value = FormatSample.example(settingsPreview.timeFormat, formatter: formatter)
        return value.isEmpty ? "—" : value
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent("Preview") {
                        Text(previewText)
                            .font(Token.Font.time(16))
                            .foregroundStyle(Token.Color.primaryText)
                            .textSelection(.enabled)
                    }
                    if draft.formatPreset == .systemDefault {
                        Text("Following your Mac's date and time format.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Picker("Format", selection: presetBinding) {
                        ForEach(TimeFormatPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }

                    if draft.formatPreset == .custom {
                        TextField("Pattern", text: patternBinding,
                                  prompt: Text(verbatim: "EEE d MMM · HH:mm"))
                            .font(.body.monospaced())
                            .focused($patternFieldFocused)

                        if !draft.isValid {
                            Label("Enter a nonempty pattern and close every quoted literal.",
                                  systemImage: "exclamationmark.circle")
                                .font(.callout)
                                .foregroundStyle(Token.Color.errorText)
                        }
                    }

                    Link(destination: URL(string: "https://martonpaulo.github.io/meantime/format.html")!) {
                        Label("Open the interactive format builder", systemImage: "curlybraces.square")
                    }
                    Link(destination: URL(string: "https://unicode.org/reports/tr35/tr35-dates.html#Date_Format_Patterns")!) {
                        Label("Advanced Unicode pattern documentation", systemImage: "book")
                    }
                } header: {
                    Text("Date and Time Format")
                } footer: {
                    Text("Choose a common preset or use Custom for any Unicode UTS-35 pattern. Quote literal words with single quotes; write two single quotes for an apostrophe.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("Menu Bar Appearance") {
                    Picker("Layout", selection: layoutBinding) {
                        Text("One item per clock").tag(MenuBarLayout.individual)
                        Text("All clocks in one item").tag(MenuBarLayout.combined)
                    }
                    .pickerStyle(.radioGroup)

                    if draft.menuBarLayout == .combined {
                        TextField("Separator", text: separatorBinding,
                                  prompt: Text(PreferenceDefaults.combinedSeparator))
                        Text("Up to \(UserInputPolicy.separatorLimit) characters. Leave empty for spacing only.")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        if preferences.clocks.contains(where: { $0.renderMode == .analogClock }) {
                            Label(
                                "Analog clocks use leading item and time in the combined item. Their analog style is preserved for individual layout.",
                                systemImage: "info.circle")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledSlider(title: String(localized: "Text size"),
                                  value: textSizeBinding,
                                  range: PreferenceDefaults.textSizeRange, unit: "pt")
                    LabeledSlider(title: String(localized: "Spacing"),
                                  value: elementSpacingBinding,
                                  range: PreferenceDefaults.elementSpacingRange, unit: "pt")
                }
            }
            .formStyle(.grouped)
            Divider()
            actionBar
        }
        .frame(width: Token.Size.paneWidth, height: Token.Size.paneHeight)
        .onAppear { settingsPreview.beginAppearanceEditing() }
        .confirmationDialog("Discard changes to Format?",
                            isPresented: $discardConfirmationShown) {
            Button("Discard Changes", role: .destructive) {
                settingsPreview.discardAppearance()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The menu bar will return to the last saved settings.")
        }
    }

    private var presetBinding: Binding<TimeFormatPreset> {
        binding(\.formatPreset)
    }

    private var patternBinding: Binding<String> {
        Binding(
            get: { draft.customPattern },
            set: { value in
                settingsPreview.beginAppearanceEditing()
                settingsPreview.appearanceDraft?.customPattern = UserInputPolicy.truncated(
                    value, limit: UserInputPolicy.patternLimit)
            })
    }

    private var layoutBinding: Binding<MenuBarLayout> {
        binding(\.menuBarLayout)
    }

    private var separatorBinding: Binding<String> {
        Binding(
            get: { draft.combinedSeparator },
            set: { value in
                settingsPreview.beginAppearanceEditing()
                settingsPreview.appearanceDraft?.combinedSeparator = UserInputPolicy.truncated(
                    value, limit: UserInputPolicy.separatorLimit)
            })
    }

    private var textSizeBinding: Binding<Double> {
        binding(\.textSize)
    }

    private var elementSpacingBinding: Binding<Double> {
        binding(\.elementSpacing)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<SettingsPreview.AppearanceDraft, Value>)
        -> Binding<Value> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { value in
                settingsPreview.beginAppearanceEditing()
                settingsPreview.appearanceDraft?[keyPath: keyPath] = value
            }
        )
    }

    private var actionBar: some View {
        HStack(spacing: Token.Space.sm) {
            Button("Cancel") {
                if settingsPreview.hasAppearanceChanges {
                    discardConfirmationShown = true
                }
            }
            .disabled(!settingsPreview.hasAppearanceChanges)
            Spacer()
            if settingsPreview.hasAppearanceChanges {
                Text("Not saved")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Unsaved changes")
            }
            Button("Save") { settingsPreview.saveAppearance() }
                .keyboardShortcut(.defaultAction)
                .disabled(!settingsPreview.hasAppearanceChanges
                          || !settingsPreview.canSaveAppearance)
        }
        .padding(Token.Space.md)
    }
}

/// A titled slider with a live value readout — one definition for every
/// appearance control.
private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: Token.Space.xxs) {
            LabeledContent(title) {
                Text("\(Int(value)) \(unit)").foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: 1)
        }
    }
}

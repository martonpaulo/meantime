import SwiftUI
import MeantimeKit

/// Preset-first time formatting and menu-bar appearance. Changes preview in
/// the real status item and persist together only after Save.
struct FormatPane: View {
    @Environment(Preferences.self) private var preferences
    @Environment(SettingsPreview.self) private var settingsPreview

    @State private var discardConfirmationShown = false
    @FocusState private var patternFieldFocused: Bool

    private var draft: SettingsPreview.AppearanceDraft {
        settingsPreview.appearanceDraft
            ?? SettingsPreview.AppearanceDraft(preferences: preferences)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
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
                            Label("Enter a pattern and close every quoted literal.",
                                  systemImage: "exclamationmark.circle")
                                .font(.callout)
                                .foregroundStyle(Token.Color.errorText)
                        }
                    }

                    if draft.formatPreset == .systemDefault {
                        Text("Uses your Mac's current date and time format.")
                            .font(Token.Font.secondary)
                            .foregroundStyle(Token.Color.secondaryText)
                    }

                    Link(destination: URL(string: "https://martonpaulo.com/meantime/format.html")!) {
                        Label("Open Format Builder", systemImage: "curlybraces.square")
                    }
                    Link(destination: URL(string: "https://unicode.org/reports/tr35/tr35-dates.html#Date_Format_Patterns")!) {
                        Label("View Advanced Format Documentation", systemImage: "book")
                    }
                } header: {
                    Text("Date and Time Format")
                } footer: {
                    Text("Choose a preset or use Custom for any Unicode UTS-35 pattern. Put literal text in single quotes and use two single quotes for an apostrophe.")
                        .font(Token.Font.secondary)
                        .foregroundStyle(Token.Color.secondaryText)
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
                        Text("Enter up to \(UserInputPolicy.separatorLimit) characters. Leave blank to use spacing only.")
                            .font(Token.Font.secondary)
                            .foregroundStyle(Token.Color.secondaryText)

                        if preferences.clocks.contains(where: { $0.renderMode == .analogClock }) {
                            Label(
                                "Combined layout shows analog clocks as a leading item and time. The analog face remains available in individual layout.",
                                systemImage: "info.circle")
                                .font(Token.Font.secondary)
                                .foregroundStyle(Token.Color.secondaryText)
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
            .scrollIndicators(.hidden)
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
                UnsavedBadge()
            }
            Button("Save") { settingsPreview.saveAppearance() }
                .keyboardShortcut(.defaultAction)
                .disabled(!settingsPreview.hasAppearanceChanges
                          || !settingsPreview.canSaveAppearance)
        }
        .padding(Token.Space.md)
    }
}

/// A titled slider with a live value readout: one definition for every
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

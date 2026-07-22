import SwiftUI
import MeantimeKit

/// Choose how the time reads: a preset with a live example, a fully custom
/// pattern, or reset to the system default. Text size and element spacing live
/// here too, with a preview at the chosen size.
struct FormatSettingsView: View {
    @Environment(Preferences.self) private var preferences
    let formatter: ClockFormatter

    @State private var customPattern = ""

    var body: some View {
        @Bindable var prefs = preferences
        Form {
            Section("Time format") {
                ForEach(TimeFormat.presets) { preset in
                    presetRow(preset, isSelected: prefs.timeFormat == preset.format) {
                        prefs.timeFormat = preset.format
                    }
                }
            }

            Section("Custom pattern") {
                HStack {
                    TextField("e.g. EEE HH:mm", text: $customPattern)
                    Button("Use") {
                        let trimmed = customPattern.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty { prefs.timeFormat = .custom(trimmed) }
                    }
                    .disabled(customPattern.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if !customPattern.trimmingCharacters(in: .whitespaces).isEmpty {
                    LabeledContent("Example") {
                        Text(FormatSample.example(.custom(customPattern), formatter: formatter))
                            .font(Token.Font.time(12))
                    }
                }
                Text("Unicode date patterns: H HH h mm ss a EEE d MMM yyyy — literals in quotes.")
                    .font(Token.Font.secondary)
                    .foregroundStyle(Token.Color.secondaryText)
                Button("Reset to system default") { prefs.timeFormat = .system }
            }

            Section("Appearance") {
                slider("Text size", value: $prefs.textSize, range: PreferenceDefaults.textSizeRange)
                slider("Element spacing", value: $prefs.elementSpacing, range: PreferenceDefaults.elementSpacingRange)
                LabeledContent("Preview") {
                    Text("\(RegionFlag.emoji(for: TimeZone.current.identifier)) \(FormatSample.example(prefs.timeFormat, formatter: formatter))")
                        .font(Token.Font.time(prefs.textSize))
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { customPattern = prefs.timeFormat.customPattern ?? "" }
    }

    private func presetRow(_ preset: TimeFormatPreset, isSelected: Bool, select: @escaping () -> Void) -> some View {
        Button(action: select) {
            HStack {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Token.Color.accent : Token.Color.secondaryText)
                Text(preset.title)
                Spacer()
                Text(FormatSample.example(preset.format, formatter: formatter))
                    .font(Token.Font.time(12))
                    .foregroundStyle(Token.Color.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.xxs) {
            LabeledContent(title) {
                Text("\(Int(value.wrappedValue)) pt").foregroundStyle(Token.Color.secondaryText)
            }
            Slider(value: value, in: range, step: 1)
        }
    }
}

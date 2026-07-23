import SwiftUI
import MeantimeKit

/// How time reads everywhere: a live preview, the Unicode pattern itself, and a
/// link to the interactive format builder on the website for assembling one.
/// System default is one click away.
struct FormatPane: View {
    @Environment(Preferences.self) private var preferences
    let formatter: ClockFormatter

    @State private var rawPattern = ""
    @FocusState private var patternFieldFocused: Bool

    var body: some View {
        @Bindable var prefs = preferences
        Form {
            Section {
                LabeledContent("Preview") {
                    Text(FormatSample.example(prefs.timeFormat, formatter: formatter))
                        .font(Token.Font.time(16))
                        .foregroundStyle(Token.Color.accent)
                }
                if prefs.timeFormat.isSystem {
                    Text("Following your Mac's time format. Type a pattern below to customize.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                TextField("Pattern", text: $rawPattern,
                          prompt: Text(verbatim: "EEE d MMM · HH:mm"))
                    .font(.body.monospaced())
                    .focused($patternFieldFocused)
                    .onChange(of: rawPattern) {
                        guard patternFieldFocused else { return }
                        applyRawPattern()
                    }
                PatternLegend(formatter: formatter)
                Link(destination: URL(string: "https://martonpaulo.github.io/meantime/format.html")!) {
                    Label("Open the interactive format builder", systemImage: "curlybraces.square")
                }
            } header: {
                Text("Time Pattern")
            } footer: {
                Text("Standard Unicode date patterns. Wrap literal text in single quotes: HH'h'mm → \(FormatSample.example(.custom("HH'h'mm"), formatter: formatter)). The builder assembles a pattern visually — copy it and paste it here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Return to your Mac's own format") {
                    Button("Use System Default") {
                        preferences.timeFormat = .system
                        rawPattern = ""
                    }
                    .disabled(prefs.timeFormat.isSystem)
                }
            }

            Section("Menu Bar Appearance") {
                LabeledSlider(title: String(localized: "Text size"),
                              value: $prefs.textSize,
                              range: PreferenceDefaults.textSizeRange, unit: "pt")
                LabeledSlider(title: String(localized: "Spacing"),
                              value: $prefs.elementSpacing,
                              range: PreferenceDefaults.elementSpacingRange, unit: "pt")
                LabeledContent("Menu bar preview") {
                    Text("\(RegionFlag.emoji(for: TimeZone.current.identifier)) \(FormatSample.example(prefs.timeFormat, formatter: formatter))")
                        .font(Token.Font.time(prefs.textSize))
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: Token.Size.paneWidth)
        .fixedSize()
        .onAppear { rawPattern = preferences.timeFormat.customPattern ?? "" }
    }

    private func applyRawPattern() {
        let trimmed = rawPattern.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        preferences.timeFormat = .custom(trimmed)
    }
}

/// The pattern vocabulary, each token rendered live so its meaning is obvious.
private struct PatternLegend: View {
    let formatter: ClockFormatter

    private static let tokens = ["H", "HH", "h", "a", "mm", "ss", "EEE", "EEEE", "d", "MMM", "yyyy"]

    private let columns = [GridItem(.adaptive(minimum: 74), spacing: Token.Space.sm)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Token.Space.xs) {
            ForEach(Self.tokens, id: \.self) { token in
                VStack(alignment: .leading, spacing: 0) {
                    Text(token)
                        .font(.caption.monospaced().weight(.semibold))
                    Text(FormatSample.example(.custom(token), formatter: formatter))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, Token.Space.xxs)
            }
        }
        .accessibilityLabel("Pattern token reference")
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

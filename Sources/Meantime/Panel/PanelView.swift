import SwiftUI
import MeantimeKit

/// Actions the panel can trigger, wired by the app so the view stays decoupled
/// from lifecycle and updates.
struct PanelActions {
    var openSettings: () -> Void
    var checkForUpdates: () -> Void
    var about: () -> Void
    var quit: () -> Void
}

/// The dropdown shown from a menu-bar item: every clock, the time-travel control,
/// and app actions. It renders prepared `PanelRow`s and observes the shared time
/// source, so it re-reads the same instant the menu bar shows.
struct PanelView: View {
    @Environment(Preferences.self) private var preferences
    @Environment(TimeSource.self) private var timeSource
    @Environment(PanelModel.self) private var panelModel

    let formatter: ClockFormatter
    let actions: PanelActions

    private var previewDate: Date { panelModel.previewDate(from: timeSource.now) }

    private var rows: [PanelRow] {
        PanelRowFormatter.rows(clocks: preferences.clocks, at: previewDate,
                               format: preferences.timeFormat, formatter: formatter)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if rows.isEmpty {
                emptyState
            } else {
                ForEach(rows) { row in
                    ClockRowView(row: row,
                                 textSize: preferences.textSize,
                                 spacing: preferences.elementSpacing)
                }
            }

            Divider().padding(.vertical, Token.Space.sm)
            TimeTravelView()
            Divider().padding(.vertical, Token.Space.sm)
            footer
        }
        .padding(Token.Space.md)
        .frame(width: Token.Size.panelWidth)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Token.Space.xs) {
            Text("No clocks yet").font(Token.Font.label)
            Button("Add a clock…") { actions.openSettings() }
                .buttonStyle(.link)
        }
        .padding(.vertical, Token.Space.sm)
    }

    private var footer: some View {
        HStack(spacing: Token.Space.sm) {
            Spacer()
            Menu {
                Button("Add Clock…") { actions.openSettings() }
                Button("Settings…") { actions.openSettings() }
                Button("Check for Updates…") { actions.checkForUpdates() }
                Divider()
                Button("About Meantime") { actions.about() }
                Button("Quit Meantime") { actions.quit() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Token.Color.secondaryText)
                    .frame(width: Token.Size.hitTarget, height: Token.Size.hitTarget, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("More")
        }
    }
}

/// One clock line: emoji, label (with an optional day caption), and the time.
private struct ClockRowView: View {
    let row: PanelRow
    let textSize: Double
    let spacing: Double

    var body: some View {
        LabeledContent {
            Text(row.time)
                .font(Token.Font.time(textSize))
                .foregroundStyle(Token.Color.primaryText)
        } label: {
            HStack(spacing: spacing + Token.Space.xs) {
                Text(row.emoji)
                VStack(alignment: .leading, spacing: 0) {
                    Text(row.label)
                        .font(Token.Font.label)
                        .foregroundStyle(Token.Color.primaryText)
                    if let caption = row.dayCaption {
                        Text(caption)
                            .font(Token.Font.secondary)
                            .foregroundStyle(Token.Color.secondaryText)
                    }
                }
            }
        }
        .padding(.vertical, Token.Space.xxs)
        .frame(minHeight: Token.Size.rowMinHeight)
        .accessibilityElement(children: .combine)
    }
}

/// The time-travel control: a slider that offsets every clock, with a live
/// offset readout and a one-tap return to now.
private struct TimeTravelView: View {
    @Environment(PanelModel.self) private var panelModel

    var body: some View {
        @Bindable var model = panelModel
        VStack(alignment: .leading, spacing: Token.Space.xs) {
            HStack {
                Label("Time travel", systemImage: "clock.arrow.2.circlepath")
                    .font(Token.Font.secondary)
                    .foregroundStyle(Token.Color.secondaryText)
                Spacer()
                Text(offsetLabel(model.travelHours))
                    .font(Token.Font.time(11))
                    .foregroundStyle(model.isTraveling ? Token.Color.accent : Token.Color.secondaryText)
                if model.isTraveling {
                    Button("Now") { withAnimation(Token.Motion.quick) { model.reset() } }
                        .buttonStyle(.link)
                        .font(Token.Font.secondary)
                }
            }
            Slider(value: $model.travelHours, in: -24 ... 24, step: 0.5)
                .controlSize(.small)
        }
    }

    private func offsetLabel(_ hours: Double) -> String {
        let totalMinutes = Int((hours * 60).rounded())
        guard totalMinutes != 0 else { return "Now" }
        let sign = totalMinutes > 0 ? "+" : "−"
        let magnitude = abs(totalMinutes)
        let h = magnitude / 60
        let m = magnitude % 60
        if h == 0 { return "\(sign)\(m)m" }
        return m == 0 ? "\(sign)\(h)h" : "\(sign)\(h)h \(m)m"
    }
}

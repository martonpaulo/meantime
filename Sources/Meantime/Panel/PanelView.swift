import SwiftUI
import MeantimeKit

/// Actions the panel can trigger, wired by the app so the view stays decoupled
/// from lifecycle. Updates and About live in Settings and the app menu.
struct PanelActions {
    var openSettings: () -> Void
    var quit: () -> Void
}

/// The menu-bar panel: every clock at a glance, a quick month calendar for
/// day checking, and typed time travel. Renders prepared `PanelRow`s and reads
/// the shared time source, so it always matches the menu bar exactly.
struct PanelView: View {
    @Environment(SettingsPreview.self) private var settingsPreview
    @Environment(TimeSource.self) private var timeSource
    @Environment(PanelModel.self) private var panelModel

    let formatter: ClockFormatter
    let actions: PanelActions
    @ScaledMetric(relativeTo: .body) private var panelWidth = Token.Size.panelWidth

    private var previewDate: Date { panelModel.previewDate(from: timeSource.now) }

    private var rows: [PanelRow] {
        PanelRowFormatter.rows(clocks: settingsPreview.clocks, at: previewDate,
                               format: settingsPreview.timeFormat, formatter: formatter)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            clockList
            PanelDivider()
            MonthCalendarView(formatter: formatter)
            PanelDivider()
            TimeTravelSection()
            PanelDivider()
            footer
        }
        .padding(.vertical, Token.Space.sm)
        .frame(width: panelWidth)
        .background(PanelBackground())
        .clipShape(RoundedRectangle(cornerRadius: Token.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Token.Radius.panel, style: .continuous)
                .strokeBorder(Token.Color.hairlineSeparator, lineWidth: Token.Size.hairline)
        )
    }

    @ViewBuilder private var clockList: some View {
        if rows.isEmpty {
            VStack(alignment: .leading, spacing: Token.Space.xs) {
                Text("No clocks yet")
                    .font(Token.Font.label)
                    .foregroundStyle(Token.Color.secondaryText)
                Button("Add a clock…") { actions.openSettings() }
                    .buttonStyle(.link)
            }
            .padding(.horizontal, Token.Space.lg)
            .padding(.vertical, Token.Space.sm)
        } else {
            Group {
                if rows.count <= 4 {
                    clockRows
                } else {
                    ScrollView {
                        clockRows
                    }
                    .scrollIndicators(.hidden)
                    .frame(height: Token.Size.panelClockListMaxHeight)
                    .accessibilityLabel("World clocks")
                }
            }
            .padding(.horizontal, Token.Space.md)
        }
    }

    private var clockRows: some View {
        LazyVStack(spacing: 0) {
            ForEach(rows) { row in
                ClockRowView(row: row, textSize: settingsPreview.textSize,
                             spacing: settingsPreview.elementSpacing)
            }
        }
    }

    /// Direct actions: no nested menus inside the menu-bar panel.
    private var footer: some View {
        HStack(spacing: Token.Space.lg) {
            FooterButton(title: String(localized: "Settings…"), symbol: "gearshape") {
                actions.openSettings()
            }
            Spacer()
            FooterButton(title: String(localized: "Quit"), symbol: "power") {
                actions.quit()
            }
        }
        .padding(.horizontal, Token.Space.xl)
        .padding(.vertical, Token.Space.sm)
    }
}

/// Quiet icon+text action for the panel footer; brightens on hover.
private struct FooterButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .labelStyle(PanelActionLabelStyle())
                .font(Token.Font.action)
                .foregroundStyle(isHovering ? Token.Color.primaryText : Token.Color.secondaryText)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .frame(minHeight: Token.Size.hitTarget)
    }
}

/// Hairline divider with the panel's standard vertical rhythm.
private struct PanelDivider: View {
    var body: some View {
        Divider().padding(.vertical, Token.Space.xxs)
    }
}

/// One clock line: emoji, label with offset/day caption, monospaced time.
private struct ClockRowView: View {
    let row: PanelRow
    let textSize: Double
    let spacing: Double
    @ScaledMetric(relativeTo: .body) private var timeScale = 1.0
    @ScaledMetric(relativeTo: .body) private var rowHeight = Token.Size.rowMinHeight

    private var caption: String {
        if let day = row.dayCaption { return "\(row.offsetCaption) · \(day)" }
        return row.offsetCaption
    }

    var body: some View {
        HStack(spacing: spacing + Token.Space.sm) {
            Text(row.adornment ?? "")
                .font(.title3)
                .frame(width: Token.Size.adornmentColumn, alignment: .center)
            VStack(alignment: .leading, spacing: 0) {
                Text(row.label)
                    .font(Token.Font.label)
                    .foregroundStyle(Token.Color.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(caption)
                    .font(Token.Font.secondary)
                    .foregroundStyle(Token.Color.secondaryText)
                    .lineLimit(1)
            }
            .layoutPriority(1)
            Spacer(minLength: Token.Space.md)
            Text(row.time)
                .font(Token.Font.time(textSize * timeScale + Token.Size.panelTimeBoost))
                .foregroundStyle(Token.Color.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(2)
        }
        .padding(.horizontal, Token.Space.sm)
        .padding(.vertical, Token.Space.sm)
        .frame(minHeight: rowHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.label), \(row.time), \(caption)")
    }
}

/// Typed time travel: no slider. Type (or step) a time to preview it across
/// every clock; "Now" returns instantly.
private struct TimeTravelSection: View {
    @Environment(PanelModel.self) private var panelModel
    @Environment(TimeSource.self) private var timeSource

    private var timeBinding: Binding<Date> {
        Binding(
            get: { panelModel.selectedTime ?? timeSource.now },
            set: { panelModel.selectedTime = $0 }
        )
    }

    private var previewSummary: String {
        panelModel.previewDate(from: timeSource.now).formatted(
            .dateTime.weekday(.abbreviated).month(.abbreviated).day().year()
                .hour().minute())
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: Token.Space.sm,
             verticalSpacing: Token.Space.xs) {
            GridRow {
                Label("Time Travel", systemImage: "clock.arrow.2.circlepath")
                    .labelStyle(PanelActionLabelStyle())
                    .font(Token.Font.action)
                    .foregroundStyle(Token.Color.secondaryText)
                HStack(spacing: Token.Space.sm) {
                    Spacer()
                    DatePicker("Time", selection: timeBinding,
                               displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.field)
                        .controlSize(.small)
                        .fixedSize()
                        .accessibilityLabel("Preview time")
                }
            }
            if panelModel.isTraveling {
                GridRow {
                    HStack(spacing: Token.Space.sm) {
                        Text("Previewing \(previewSummary)")
                            .font(Token.Font.secondary)
                            .foregroundStyle(Token.Color.primaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("Previewing \(previewSummary)")
                        Spacer(minLength: Token.Space.xs)
                        Button("Now") {
                            withAnimation(Token.Motion.quick) { panelModel.reset() }
                        }
                        .buttonStyle(.link)
                        .font(Token.Font.action)
                        .help("Return to the current date and time")
                        .accessibilityLabel("Return to now")
                    }
                    .gridCellColumns(2)
                }
            }
        }
        .padding(.horizontal, Token.Space.xl)
        .padding(.vertical, Token.Space.xs)
    }
}

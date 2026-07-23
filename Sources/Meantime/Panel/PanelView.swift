import SwiftUI
import MeantimeKit

/// Actions the panel can trigger, wired by the app so the view stays decoupled
/// from lifecycle. Updates and About live in Settings and the app menu.
struct PanelActions {
    var openSettings: () -> Void
    var quit: () -> Void
}

/// The menu-bar dropdown: every clock at a glance, a quick month calendar for
/// day checking, and typed time travel. Renders prepared `PanelRow`s and reads
/// the shared time source, so it always matches the menu bar exactly.
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
            clockList
            PanelDivider()
            MonthCalendarView(formatter: formatter)
            PanelDivider()
            TimeTravelSection()
            PanelDivider()
            footer
        }
        .padding(.vertical, Token.Space.xs)
        .frame(width: Token.Size.panelWidth)
        .background(PanelBackground())
        .clipShape(RoundedRectangle(cornerRadius: Token.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Token.Radius.panel, style: .continuous)
                .strokeBorder(Token.Color.separator.opacity(0.5), lineWidth: 0.5)
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
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    ClockRowView(row: row, textSize: preferences.textSize,
                                 spacing: preferences.elementSpacing)
                }
            }
            .padding(.horizontal, Token.Space.sm)
        }
    }

    /// Direct actions — no nested menus inside a menu-bar dropdown.
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
        .padding(.horizontal, Token.Space.lg)
        .padding(.top, Token.Space.xs)
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

    private var caption: String {
        if let day = row.dayCaption { return "\(row.offsetCaption) · \(day)" }
        return row.offsetCaption
    }

    var body: some View {
        HStack(spacing: spacing + Token.Space.xs) {
            Text(row.adornment ?? "")
                .font(Token.Font.label)
                .frame(width: Token.Size.adornmentColumn, alignment: .center)
            VStack(alignment: .leading, spacing: 0) {
                Text(row.label)
                    .font(Token.Font.label)
                    .foregroundStyle(Token.Color.primaryText)
                Text(caption)
                    .font(Token.Font.secondary)
                    .foregroundStyle(Token.Color.secondaryText)
            }
            Spacer(minLength: Token.Space.md)
            Text(row.time)
                .font(Token.Font.time(textSize))
                .foregroundStyle(Token.Color.primaryText)
        }
        .padding(.horizontal, Token.Space.sm)
        .padding(.vertical, Token.Space.xs)
        .frame(minHeight: Token.Size.rowMinHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.label), \(row.time), \(caption)")
    }
}

/// Quick month calendar for checking which weekday a date falls on. Picking a
/// day previews it across all clocks; it resets when the panel closes.
private struct CalendarSection: View {
    @Environment(PanelModel.self) private var panelModel
    @Environment(TimeSource.self) private var timeSource

    private var dayBinding: Binding<Date> {
        Binding(
            get: { panelModel.selectedDay ?? timeSource.now },
            set: { panelModel.selectedDay = $0 }
        )
    }

    var body: some View {
        DatePicker("Calendar", selection: dayBinding, displayedComponents: [.date])
            .datePickerStyle(.graphical)
            .labelsHidden()
            .focusEffectDisabled()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, Token.Space.md)
            .accessibilityLabel("Month calendar")
    }
}

/// Typed time travel — no slider. Type (or step) a time to preview it across
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

    var body: some View {
        HStack(spacing: Token.Space.sm) {
            Label("Time travel", systemImage: "clock.arrow.2.circlepath")
                .labelStyle(PanelActionLabelStyle())
                .font(Token.Font.action)
                .foregroundStyle(Token.Color.secondaryText)
            Spacer()
            if panelModel.isTraveling {
                Button("Now") {
                    withAnimation(Token.Motion.quick) { panelModel.reset() }
                }
                .buttonStyle(.link)
                .font(Token.Font.action)
                .help("Back to the current time")
            }
            DatePicker("Time", selection: timeBinding, displayedComponents: [.hourAndMinute])
                .datePickerStyle(.field)
                .controlSize(.small)
                .fixedSize()
                .accessibilityLabel("Time travel preview time")
        }
        .padding(.horizontal, Token.Space.lg)
    }
}

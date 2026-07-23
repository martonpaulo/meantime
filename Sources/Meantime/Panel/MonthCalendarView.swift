import SwiftUI
import MeantimeKit

/// The panel's quick month calendar — the Windows-style "which day is that"
/// glance, drawn to match the panel. Browsing months is free; picking a day
/// previews it across every clock (transient, resets with the panel).
struct MonthCalendarView: View {
    @Environment(PanelModel.self) private var panelModel
    @Environment(TimeSource.self) private var timeSource

    let formatter: ClockFormatter

    private var calendar: Calendar { .current }
    private var visibleMonth: Date { panelModel.displayedMonth ?? timeSource.now }
    private var grid: MonthGrid { MonthGrid.make(containing: visibleMonth, calendar: calendar) }

    private var monthTitle: String {
        formatter.string(for: grid.monthStart, timeZone: .current, format: .custom("MMMM yyyy"))
    }

    var body: some View {
        VStack(spacing: Token.Space.xs) {
            header
            weekdayRow
            ForEach(Array(grid.weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week) { day in
                        DayCell(day: day,
                                isSelected: isSelected(day),
                                isToday: calendar.isDate(day.date, inSameDayAs: timeSource.now)) {
                            select(day)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Token.Space.lg)
    }

    private var header: some View {
        HStack(spacing: Token.Space.sm) {
            Text(monthTitle)
                .font(Token.Font.label.weight(.semibold))
                .foregroundStyle(Token.Color.primaryText)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            CalendarNavButton(symbol: "chevron.left", label: "Previous month") { step(-1) }
            CalendarNavButton(symbol: "circle.fill", label: "Current month") {
                panelModel.displayedMonth = nil
            }
            CalendarNavButton(symbol: "chevron.right", label: "Next month") { step(1) }
        }
        .padding(.bottom, Token.Space.xxs)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(MonthGrid.weekdaySymbols(calendar: calendar).enumerated()),
                    id: \.offset) { _, symbol in
                Text(symbol)
                    .font(Token.Font.secondary.weight(.medium))
                    .foregroundStyle(Token.Color.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func isSelected(_ day: MonthGrid.Day) -> Bool {
        guard let selected = panelModel.selectedDay else { return false }
        return calendar.isDate(day.date, inSameDayAs: selected)
    }

    private func select(_ day: MonthGrid.Day) {
        withAnimation(Token.Motion.quick) {
            // Re-picking the selected day (or today with nothing else traveled)
            // clears the day selection — tap to peek, tap to come back.
            if isSelected(day) {
                panelModel.selectedDay = nil
            } else if calendar.isDate(day.date, inSameDayAs: timeSource.now) {
                panelModel.selectedDay = nil
            } else {
                panelModel.selectedDay = day.date
            }
            if !day.isInMonth {
                panelModel.displayedMonth = day.date
            }
        }
    }

    private func step(_ months: Int) {
        panelModel.displayedMonth = calendar.date(byAdding: .month, value: months, to: visibleMonth)
    }
}

/// Small chevron/today button used by the calendar header.
private struct CalendarNavButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: symbol == "circle.fill" ? 7 : 11, weight: .semibold))
                .foregroundStyle(Token.Color.secondaryText)
                .frame(width: Token.Size.hitTarget, height: Token.Size.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// One day: accent-filled when selected, accent-tinted when today, dimmed when
/// outside the visible month.
private struct DayCell: View {
    let day: MonthGrid.Day
    let isSelected: Bool
    let isToday: Bool
    let select: () -> Void

    @State private var isHovering = false

    private var textColor: Color {
        if isSelected { return .white }
        if isToday { return Token.Color.accent }
        return day.isInMonth ? Token.Color.primaryText : Token.Color.secondaryText.opacity(0.5)
    }

    var body: some View {
        Button(action: select) {
            Text("\(day.dayNumber)")
                .font(Token.Font.secondary.weight(isToday || isSelected ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, minHeight: Token.Size.calendarCell)
                .background {
                    if isSelected {
                        Circle().fill(Token.Color.accent)
                            .frame(width: Token.Size.calendarSelection,
                                   height: Token.Size.calendarSelection)
                    } else if isHovering {
                        Circle().fill(Token.Color.rowHighlight)
                            .frame(width: Token.Size.calendarSelection,
                                   height: Token.Size.calendarSelection)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel("Day \(day.dayNumber)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

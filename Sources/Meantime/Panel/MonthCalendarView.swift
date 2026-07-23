import SwiftUI
import MeantimeKit

/// The panel's quick month calendar: the Windows-style "which day is that"
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
        VStack(spacing: Token.Space.sm) {
            header
            Grid(horizontalSpacing: Token.Space.xs, verticalSpacing: Token.Space.xs) {
                GridRow {
                    ForEach(Array(MonthGrid.weekdaySymbols(calendar: calendar).enumerated()),
                            id: \.offset) { index, symbol in
                        Text(symbol)
                            .font(Token.Font.secondary.weight(.medium))
                            .foregroundStyle(isWeekendColumn(index)
                                ? Token.Color.weekendText : Token.Color.secondaryText)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(calendar.weekdaySymbols[
                                (calendar.firstWeekday - 1 + index) % 7])
                            .accessibilityValue(isWeekendColumn(index) ? "Weekend" : "Weekday")
                    }
                }
                ForEach(Array(grid.weeks.enumerated()), id: \.offset) { _, week in
                    GridRow {
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
        }
        .padding(.horizontal, Token.Space.xl)
        .padding(.vertical, Token.Space.xs)
    }

    private var header: some View {
        HStack(spacing: Token.Space.xs) {
            Text(monthTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Token.Color.primaryText)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            CalendarNavButton(symbol: "chevron.left.2", label: "Previous year") { step(years: -1) }
            CalendarNavButton(symbol: "chevron.left", label: "Previous month") { step(months: -1) }
            Button("Today") {
                withAnimation(Token.Motion.quick) {
                    panelModel.returnToToday()
                }
            }
            .buttonStyle(.plain)
            .font(Token.Font.calendarNavigation)
            .foregroundStyle(Token.Color.secondaryText)
            .help("Return to the current month")
            CalendarNavButton(symbol: "chevron.right", label: "Next month") { step(months: 1) }
            CalendarNavButton(symbol: "chevron.right.2", label: "Next year") { step(years: 1) }
        }
        .padding(.bottom, Token.Space.xs)
    }

    private func isWeekendColumn(_ index: Int) -> Bool {
        grid.weeks.first?[index].isWeekend == true
    }

    private func isSelected(_ day: MonthGrid.Day) -> Bool {
        let activeDay = panelModel.selectedDay ?? timeSource.now
        return calendar.isDate(day.date, inSameDayAs: activeDay)
    }

    private func select(_ day: MonthGrid.Day) {
        withAnimation(Token.Motion.quick) {
            // Re-picking the selected day (or today with nothing else traveled)
            // clears the day selection: tap to peek, tap to come back.
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

    private func step(months: Int) {
        panelModel.displayedMonth = calendar.date(byAdding: .month, value: months, to: visibleMonth)
    }

    private func step(years: Int) {
        panelModel.displayedMonth = calendar.date(byAdding: .year, value: years, to: visibleMonth)
    }
}

/// Small chevron/today button used by the calendar header.
private struct CalendarNavButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @ScaledMetric(relativeTo: .caption) private var hitTarget = Token.Size.hitTarget

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(Token.Font.calendarNavigation)
                .foregroundStyle(Token.Color.secondaryText)
                .frame(width: hitTarget, height: hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}

/// One day: a thin accent ring when selected, accent text for weekends and
/// today, and reduced contrast outside the visible month.
private struct DayCell: View {
    let day: MonthGrid.Day
    let isSelected: Bool
    let isToday: Bool
    let select: () -> Void

    @State private var isHovering = false
    @ScaledMetric(relativeTo: .callout) private var cellHeight = Token.Size.calendarCell
    @ScaledMetric(relativeTo: .callout) private var selectionSize = Token.Size.calendarSelection

    private var accessibilityLabel: String {
        day.date.formatted(
            .dateTime.weekday(.wide).month(.wide).day().year())
    }

    private var accessibilityState: String {
        var states: [String] = []
        states.append(day.isWeekend ? "Weekend" : "Weekday")
        if isToday { states.append("Today") }
        if isSelected { states.append("Selected") }
        if !day.isInMonth { states.append("Outside the displayed month") }
        return states.joined(separator: ", ")
    }

    private var textColor: Color {
        if isToday { return Token.Color.accent }
        if day.isWeekend, day.isInMonth { return Token.Color.weekendText }
        return day.isInMonth ? Token.Color.primaryText : Token.Color.subordinateText
    }

    var body: some View {
        Button(action: select) {
            Text("\(day.dayNumber)")
                .font(Token.Font.calendarDay.weight(isToday || isSelected ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, minHeight: cellHeight)
                .background {
                    if isSelected {
                        Circle().strokeBorder(Token.Color.accent, lineWidth: Token.Size.selectionStroke)
                            .frame(width: selectionSize, height: selectionSize)
                    } else if isHovering {
                        Circle().fill(Token.Color.rowHighlight)
                            .frame(width: selectionSize, height: selectionSize)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityState)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

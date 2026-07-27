import SwiftUI
import MeantimeKit

/// A row of seven day toggles, in the reading order of the user's own calendar
/// (Sunday first in the US, Monday first in most of Europe).
///
/// Built from native `Toggle`s in button style, so hover, pressed, disabled,
/// focus ring, and the VoiceOver on/off value all come from the platform. The
/// compact symbols are deliberately ambiguous ("T" is both Tuesday and
/// Thursday), so every button carries the full day name as its help text and
/// accessibility label.
struct WeekdayPicker: View {
    @Binding var days: Set<Weekday>

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        HStack(spacing: Token.Space.xxs) {
            ForEach(Weekday.ordered(for: calendar), id: \.self) { day in
                let name = WeekdayLabel.full(day, locale: locale)
                Toggle(isOn: binding(for: day)) {
                    Text(WeekdayLabel.compact(day, locale: locale))
                        .frame(minWidth: Token.Size.dayToggle)
                }
                .toggleStyle(.button)
                // Ideal size, so the seven stay a compact group instead of
                // stretching to fill the settings row.
                .fixedSize()
                .help(name)
                .accessibilityLabel(name)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Days"))
    }

    private func binding(for day: Weekday) -> Binding<Bool> {
        Binding(
            get: { days.contains(day) },
            set: { isOn in
                // Turning off the last day is reported by validation rather than
                // silently refused, so the sheet can say what a schedule needs.
                if isOn { days.insert(day) } else { days.remove(day) }
            })
    }
}

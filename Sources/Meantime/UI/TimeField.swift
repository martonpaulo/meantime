import SwiftUI
import MeantimeKit

/// A fixed-width, locale-aware segmented time editor: `[h]:[mm]` on a 24-hour
/// locale and `[h]:[mm] [AM/PM]` on a 12-hour one. Each numeric segment holds
/// one or two monospaced digits over a reserved two-digit box, so the control
/// never changes width while editing. All parsing, normalization, validation,
/// and formatting live in `TimeOfDayInput`; this view only renders segments and
/// commits their raw strings, reverting incomplete or invalid input.
///
/// The bound `Date` maps 1:1 to the wall-clock time in `timeZone`: the panel's
/// time travel edits in the local zone, while a clock's schedule edits in a
/// fixed zone so a typed "5:11 PM" stays 5:11.
struct TimeField: View {
    @Binding var date: Date
    var timeZone: TimeZone = .current
    var accessibilityLabel: String?

    @Environment(\.locale) private var locale

    fileprivate enum Segment: Hashable { case hour, minute }
    @FocusState private var focused: Segment?

    @State private var hourText = ""
    @State private var minuteText = ""
    @State private var meridiem: TimeOfDayInput.Meridiem = .am

    private var uses12Hour: Bool { TimeOfDayInput.uses12Hour(locale: locale) }

    var body: some View {
        HStack(spacing: Token.Space.xxxs) {
            // Hour hugs the colon (trailing), minute follows it (leading), as in
            // native time fields, so a single-digit hour never floats mid-box.
            digitSegment(text: $hourText, segment: .hour, alignment: .trailing,
                         label: String(localized: "Hour"), autoAdvancesTo: .minute)
            Text(verbatim: ":")
                .monospacedDigit()
                .foregroundStyle(Token.Color.primaryText)
            digitSegment(text: $minuteText, segment: .minute, alignment: .leading,
                         label: String(localized: "Minutes"), autoAdvancesTo: nil)
            if uses12Hour {
                meridiemToggle
                    .padding(.leading, Token.Space.xs)
            }
        }
        .padding(.horizontal, Token.Space.sm)
        .padding(.vertical, Token.Space.xxs)
        .background(
            RoundedRectangle(cornerRadius: Token.Radius.sm, style: .continuous)
                .fill(Token.Color.controlFill))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel ?? String(localized: "Time"))
        .onAppear { syncFromDate() }
        .onChange(of: date) { _, _ in if focused == nil { syncFromDate() } }
        .onChange(of: locale) { _, _ in if focused == nil { syncFromDate() } }
        .onChange(of: focused) { _, newValue in
            // Committing when focus leaves every segment (tabbing to the meridiem
            // toggle, clicking away, or another control) mirrors native fields.
            if newValue == nil { commit() }
        }
    }

    /// One numeric segment: a monospaced field over a reserved two-digit box so
    /// its width never shifts between one and two digits. The reserved box and
    /// alignment keep the digits sitting against the colon, native-style.
    private func digitSegment(text: Binding<String>, segment: Segment,
                              alignment: TextAlignment,
                              label: String, autoAdvancesTo next: Segment?) -> some View {
        Text(verbatim: "00")
            .monospacedDigit()
            .hidden()
            .overlay {
                TextField("", text: text)
                    .textFieldStyle(.plain)
                    // Without this a text field reserves a line of vertical space
                    // for its (here empty) label, so the digits render a full line
                    // below the reserved box and outside the control's background.
                    .labelsHidden()
                    .multilineTextAlignment(alignment)
                    .monospacedDigit()
                    .focused($focused, equals: segment)
                    .accessibilityLabel(label)
                    .onSubmit(commit)
                    .onChange(of: text.wrappedValue) { _, raw in
                        let sanitized = TimeOfDayInput.sanitizedDigits(raw)
                        if sanitized != raw { text.wrappedValue = sanitized }
                        // Only advance on real typing (focus is on this segment),
                        // never when syncing or committing rewrites the value.
                        if let next, focused == segment, sanitized.count == 2 {
                            focused = next
                        }
                    }
            }
    }

    /// AM/PM control on a 12-hour locale. A reserved box sized to the wider of
    /// the two keeps the whole field's width stable when the label flips.
    private var meridiemToggle: some View {
        ZStack {
            Text(meridiemLabel(.am)).hidden()
            Text(meridiemLabel(.pm)).hidden()
        }
        .overlay {
            Button {
                meridiem = meridiem.toggled
                commit()
            } label: {
                Text(meridiemLabel(meridiem))
                    .foregroundStyle(Token.Color.primaryText)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Toggle AM and PM")
            .accessibilityLabel(String(localized: "AM or PM"))
            .accessibilityValue(meridiemLabel(meridiem))
        }
    }

    private func meridiemLabel(_ value: TimeOfDayInput.Meridiem) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        return value == .am ? (formatter.amSymbol ?? "AM") : (formatter.pmSymbol ?? "PM")
    }

    // MARK: - Model bridging

    /// Rewrites the segment strings from the bound date, unless a segment is
    /// being edited (so an external tick never clobbers in-progress typing).
    private func syncFromDate() {
        let time = timeOfDay(from: date)
        let segments = TimeOfDayInput.segments(for: time, locale: locale)
        if hourText != segments.hour { hourText = segments.hour }
        if minuteText != segments.minute { minuteText = segments.minute }
        if let meridiemValue = segments.meridiem { meridiem = meridiemValue }
    }

    /// Parses the segments; on success updates the bound date and reformats to
    /// the normalized value, otherwise reverts to the last valid date.
    private func commit() {
        guard let parsed = TimeOfDayInput.parse(
            hour: hourText, minute: minuteText,
            meridiem: uses12Hour ? meridiem : nil, locale: locale) else {
            syncFromDate()
            return
        }
        let updated = date(applying: parsed, to: date)
        if updated != date { date = updated }
        // Reflect normalization ("15" -> "3 PM", "5" -> "05") in the segments.
        let segments = TimeOfDayInput.segments(for: parsed, locale: locale)
        hourText = segments.hour
        minuteText = segments.minute
        if let meridiemValue = segments.meridiem { meridiem = meridiemValue }
    }

    private func timeOfDay(from date: Date) -> TimeOfDayInput.Time {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return TimeOfDayInput.Time(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    private func date(applying time: TimeOfDayInput.Time, to base: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var parts = calendar.dateComponents([.year, .month, .day], from: base)
        parts.hour = time.hour
        parts.minute = time.minute
        parts.second = 0
        return calendar.date(from: parts) ?? base
    }
}

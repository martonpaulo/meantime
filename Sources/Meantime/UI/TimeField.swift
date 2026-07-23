import SwiftUI

/// A compact hour-and-minute entry that reads as one tidy pill. It renders the time as a
/// single formatted string, so the colon sits naturally in the text run (centered) instead
/// of a segmented picker's off-center separator, and parses typed input through the same
/// style. Digits are monospaced so the value never jitters. The bound `Date` maps 1:1 to
/// the wall-clock time in `timeZone`: the panel's time travel edits in the local zone,
/// while a clock's schedule edits in a fixed zone so a typed "5:11 PM" stays 5:11.
struct TimeField: View {
    @Binding var date: Date
    var timeZone: TimeZone = .current
    var accessibilityLabel: String?

    private var format: Date.FormatStyle {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return style
    }

    var body: some View {
        TextField("Time", value: $date, format: format)
            .textFieldStyle(.plain)
            .labelsHidden()
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .fixedSize()
            .padding(.horizontal, Token.Space.sm)
            .padding(.vertical, Token.Space.xxs)
            .background(
                RoundedRectangle(cornerRadius: Token.Radius.sm, style: .continuous)
                    .fill(Token.Color.controlFill))
            .accessibilityLabel(accessibilityLabel ?? "Time")
    }
}

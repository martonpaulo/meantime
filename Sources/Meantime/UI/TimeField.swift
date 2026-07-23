import AppKit
import SwiftUI

/// A compact, native hour-and-minute entry that reads as one clean field instead of the
/// default stepper control. Wraps `NSDatePicker` so the displayed wall-clock time maps
/// 1:1 to the bound `Date` in the given `timeZone`: the panel's time travel edits in the
/// local zone, while a clock's schedule edits in a fixed zone so a typed "5 PM" is stored
/// and shown as 5 PM (then interpreted at runtime in the clock's own zone).
struct TimeField: NSViewRepresentable {
    @Binding var date: Date
    /// The zone the field displays and edits in. Local by default.
    var timeZone: TimeZone = .current
    var controlSize: NSControl.ControlSize = .regular
    var accessibilityLabel: String?

    func makeNSView(context: Context) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textField
        picker.datePickerElements = .hourMinute
        picker.isBezeled = true
        picker.drawsBackground = false
        picker.controlSize = controlSize
        picker.font = .monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize(for: controlSize), weight: .regular)
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.dateChanged(_:))
        picker.setContentHuggingPriority(.required, for: .horizontal)
        picker.setContentCompressionResistancePriority(.required, for: .horizontal)
        apply(to: picker)
        return picker
    }

    func updateNSView(_ picker: NSDatePicker, context: Context) {
        apply(to: picker)
    }

    private func apply(to picker: NSDatePicker) {
        picker.calendar = Self.calendar(for: timeZone)
        picker.timeZone = timeZone
        if picker.dateValue != date { picker.dateValue = date }
        picker.setAccessibilityLabel(accessibilityLabel)
    }

    func makeCoordinator() -> Coordinator { Coordinator(date: $date) }

    private static func calendar(for timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    @MainActor
    final class Coordinator: NSObject {
        private let date: Binding<Date>
        init(date: Binding<Date>) { self.date = date }

        @objc func dateChanged(_ sender: NSDatePicker) {
            date.wrappedValue = sender.dateValue
        }
    }
}

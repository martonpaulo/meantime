import SwiftUI
import MeantimeKit

extension Binding where Value == String? {
    /// Bridges an optional-string model to a `TextField`: empty text stores nil,
    /// so a cleared field falls back to the derived default.
    func orEmpty() -> Binding<String> {
        Binding<String>(
            get: { wrappedValue ?? "" },
            set: { wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

/// Renders a small live example of a time format for the settings previews so
/// every choice shows exactly what it will look like.
enum FormatSample {
    static func example(_ format: TimeFormat, formatter: ClockFormatter,
                        now: Date = Date(), zone: TimeZone = .current) -> String {
        formatter.string(for: now, timeZone: zone, format: format)
    }
}

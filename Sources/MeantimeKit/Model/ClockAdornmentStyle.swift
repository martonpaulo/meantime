import Foundation

/// The optional content shown before a clock's time and identity.
///
/// The mode is stored separately from custom values so switching between text
/// and emoji never reinterprets one value as the other. `none` is deliberate;
/// an empty custom value is not used as a hidden fallback state.
public enum ClockAdornmentStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case flag
    case emoji
    case text
    case none

    public var id: String { rawValue }

    public var requiresCustomValue: Bool {
        self == .emoji || self == .text
    }
}

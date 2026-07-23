import Foundation

/// The appearance settings that must preview and persist as one user decision.
public struct MenuBarAppearance: Codable, Equatable, Sendable {
    public var timeFormat: TimeFormat
    public var layout: MenuBarLayout
    public var combinedSeparator: String
    public var textSize: Double
    public var elementSpacing: Double

    public init(timeFormat: TimeFormat, layout: MenuBarLayout,
                combinedSeparator: String, textSize: Double,
                elementSpacing: Double) {
        self.timeFormat = timeFormat
        self.layout = layout
        self.combinedSeparator = combinedSeparator
        self.textSize = textSize
        self.elementSpacing = elementSpacing
    }
}


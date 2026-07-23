import Foundation

public struct PanelSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct PanelRect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double { x }
    public var maxX: Double { x + width }
    public var midX: Double { x + width / 2 }
    public var minY: Double { y }
    public var maxY: Double { y + height }
}

/// Pure screen-edge placement used by the AppKit panel controller and tests.
public enum PanelPlacement {
    public static func frame(panelSize: PanelSize, anchor: PanelRect,
                             visibleScreen: PanelRect, gap: Double,
                             margin: Double) -> PanelRect {
        let availableWidth = max(0, visibleScreen.width - 2 * margin)
        let availableHeight = max(0, visibleScreen.height - 2 * margin)
        let width = min(panelSize.width, availableWidth)
        let height = min(panelSize.height, availableHeight)

        let centeredX = anchor.midX - width / 2
        let minX = visibleScreen.minX + margin
        let maxX = visibleScreen.maxX - margin - width
        let x = min(max(centeredX, minX), maxX)

        let preferredY = anchor.minY - gap - height
        let y = max(preferredY, visibleScreen.minY + margin)
        return PanelRect(x: x, y: y, width: width, height: height)
    }
}


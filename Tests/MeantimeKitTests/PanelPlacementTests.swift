import Foundation
import Testing
@testable import MeantimeKit

@Suite struct PanelPlacementTests {
    let screen = PanelRect(x: 100, y: 50, width: 1_200, height: 800)
    let panel = PanelSize(width: 340, height: 620)

    @Test func centersUnderAnchorWhenSpaceAllows() {
        let anchor = PanelRect(x: 650, y: 850, width: 40, height: 24)
        let frame = PanelPlacement.frame(panelSize: panel, anchor: anchor,
                                         visibleScreen: screen, gap: 5, margin: 8)
        #expect(frame.midX == anchor.midX)
        #expect(frame.maxY == anchor.minY - 5)
    }

    @Test func clampsAtBothHorizontalScreenEdges() {
        let left = PanelPlacement.frame(
            panelSize: panel, anchor: PanelRect(x: 90, y: 850, width: 20, height: 24),
            visibleScreen: screen, gap: 5, margin: 8)
        let right = PanelPlacement.frame(
            panelSize: panel, anchor: PanelRect(x: 1_295, y: 850, width: 20, height: 24),
            visibleScreen: screen, gap: 5, margin: 8)

        #expect(left.minX == screen.minX + 8)
        #expect(right.maxX == screen.maxX - 8)
    }

    @Test func neverPlacesPanelBelowVisibleScreen() {
        let frame = PanelPlacement.frame(
            panelSize: PanelSize(width: 340, height: 900),
            anchor: PanelRect(x: 650, y: 850, width: 40, height: 24),
            visibleScreen: screen, gap: 5, margin: 8)
        #expect(frame.minY >= screen.minY + 8)
        #expect(frame.height <= screen.height - 16)
    }
}

import AppKit
import MeantimeKit
import SwiftUI

/// A borderless, menu-material panel anchored flush under a status item —
/// the Control-Center presentation, not an arrowed popover. Closes on outside
/// click (key loss), Escape, or a second click on the status item.
final class PanelWindow: NSPanel {
    // Borderless panels refuse key status by default; the time-travel fields
    // need it, and `.nonactivatingPanel` keeps the app itself in the background.
    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        close()
    }

    // The Window menu's Close (⌘W) targets the key window; a borderless panel
    // has no close button, so route it to a plain close instead of a beep.
    override func performClose(_ sender: Any?) {
        close()
    }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: PanelWindow
    private let hosting: NSHostingView<AnyView>
    /// Fired after the panel shows or closes so the ticker can adapt cadence.
    var onVisibilityChange: ((Bool) -> Void)?

    var isShown: Bool { panel.isVisible }

    init(content: AnyView) {
        hosting = NSHostingView(rootView: content)
        hosting.sizingOptions = [.intrinsicContentSize]

        panel = PanelWindow(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentView = hosting
        super.init()
        panel.delegate = self
    }

    func toggle(from button: NSStatusBarButton) {
        if isShown {
            close()
        } else {
            show(from: button)
        }
    }

    func show(from button: NSStatusBarButton) {
        guard let buttonWindow = button.window, let screen = buttonWindow.screen else { return }

        // The hosting view has no size until its first layout pass; force one
        // so the panel opens at its real content size, never 0×0.
        hosting.layoutSubtreeIfNeeded()
        var size = hosting.fittingSize
        if size.width < 1 || size.height < 1 {
            size = hosting.intrinsicContentSize
        }
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))

        let placement = PanelPlacement.frame(
            panelSize: PanelSize(width: size.width, height: size.height),
            anchor: PanelRect(x: buttonFrame.minX, y: buttonFrame.minY,
                              width: buttonFrame.width, height: buttonFrame.height),
            visibleScreen: PanelRect(
                x: screen.visibleFrame.minX, y: screen.visibleFrame.minY,
                width: screen.visibleFrame.width, height: screen.visibleFrame.height),
            gap: Token.Size.panelGap,
            margin: Token.Size.screenMargin)
        panel.setFrame(
            NSRect(x: placement.x, y: placement.y,
                   width: placement.width, height: placement.height),
            display: false)
        panel.makeKeyAndOrderFront(nil)
        // Open unfocused: no control should grab a focus ring on a glance
        // surface. Tabbing or clicking still hands focus out normally.
        panel.makeFirstResponder(nil)
        onVisibilityChange?(true)
    }

    func close() {
        guard isShown else { return }
        panel.close()
        onVisibilityChange?(false)
    }

    func windowDidResignKey(_ notification: Notification) {
        // Key loss = the user clicked elsewhere; a menu-style surface dismisses.
        close()
    }
}

/// The system menu material behind the panel content, so the surface matches
/// native menu-bar dropdowns in both appearances.
struct PanelBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        // This borderless, arrowless status-item surface has menu semantics.
        // Apple's dedicated menu material matches native menu-bar dropdowns.
        view.material = .menu
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

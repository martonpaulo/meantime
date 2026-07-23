import AppKit
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

        // Centered under the item, clamped inside the screen, flush to the bar.
        var x = buttonFrame.midX - size.width / 2
        let minX = screen.visibleFrame.minX + Token.Size.screenMargin
        let maxX = screen.visibleFrame.maxX - size.width - Token.Size.screenMargin
        x = min(max(x, minX), maxX)
        let y = buttonFrame.minY - Token.Size.panelGap - size.height

        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: false)
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
        // Popover material matches Control-Center-style anchored surfaces (menu
        // material reads darker than the menu bar it hangs from).
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

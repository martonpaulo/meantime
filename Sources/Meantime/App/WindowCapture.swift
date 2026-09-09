#if DEBUG
import AppKit
import MeantimeKit
import SwiftUI

/// Debug-only on-screen capture support for documentation screenshots.
///
/// Opens exactly one production window, fixed to a size that does not depend on
/// this machine, activates it, and prints its window id so a script can call
/// `screencapture -l<id>`. Capturing the real window on screen is the only way
/// to keep the macOS window shadow, corner radius, material and elevation: an
/// offscreen bitmap of the same view has none of them, and rendering larger
/// does not bring them back.
///
/// Only the app's own windows are ever opened or named here.
@MainActor
enum WindowCapture {
    /// The windows a capture run can ask for, in the order the script uses them.
    enum Subject: String, CaseIterable {
        case panel
        case settingsClocks = "settings-clocks"
        case settingsFormat = "settings-format"
        case settingsGeneral = "settings-general"
    }

    private static var retained: [NSWindow] = []

    /// Opens `subject`, prints `SCALE`, `WINDOW_ID` and finally `READY`, and
    /// keeps the app alive until the caller terminates it.
    static func present(_ subject: Subject) {
        let preferences = Preferences(store: EphemeralPreferenceStore())
        // A fixed fixture: the same clocks, layout and format on any machine.
        preferences.clocks = [
            WorldClock(timeZoneID: "America/Recife", customLabel: "Recife"),
            WorldClock(timeZoneID: "Europe/Madrid", customLabel: "Madrid"),
        ]
        preferences.menuBarLayout = .individual
        let preview = SettingsPreview(preferences: preferences)
        let editing = ClockEditingSession(preferences: preferences, settingsPreview: preview)
        let formatter = ClockFormatter()

        let window: NSWindow
        switch subject {
        case .panel:
            window = panelWindow(preferences: preferences, preview: preview, formatter: formatter)
        case .settingsClocks:
            window = paneWindow(ClocksPane(formatter: formatter)
                .environment(preferences).environment(preview).environment(editing))
        case .settingsFormat:
            window = paneWindow(FormatPane()
                .environment(preferences).environment(preview))
        case .settingsGeneral:
            window = paneWindow(GeneralPane(updateManager: UpdateManager())
                .environment(preferences))
        }

        retained.append(window)
        // Meantime is an accessory app, which cannot take real key focus. The
        // traffic lights and control tints only render active when it can, so
        // the capture run promotes itself to a regular app for its lifetime.
        NSApp.setActivationPolicy(.regular)
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        let scale = window.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        print("SCALE \(scale)")
        print("WINDOW_ID \(window.windowNumber)")

        // The traffic lights and control tints only come out coloured when the
        // window is genuinely key at the moment of capture, and that state is
        // settled a few run-loop turns after ordering front. Re-activate, then
        // announce readiness, so the script never fires early.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                print("KEY \(window.isKeyWindow) MAIN \(window.isMainWindow)")
                print("READY")
                fflush(stdout)
            }
        }
    }

    private static func paneWindow(_ view: some View) -> NSWindow {
        let hosting = NSHostingController(rootView: AnyView(view.preferredColorScheme(.dark)))
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.title = "Meantime Settings"
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        // Fixed to the design tokens, so the capture is the same on any display.
        window.setContentSize(NSSize(width: Token.Size.paneWidth, height: Token.Size.paneHeight))
        return window
    }

    private static func panelWindow(preferences: Preferences, preview: SettingsPreview,
                                    formatter: ClockFormatter) -> NSWindow {
        let timeSource = TimeSource(now: ISO8601DateFormatter().date(from: "2026-07-23T15:11:00Z")!)
        let root = PanelView(formatter: formatter,
                             actions: PanelActions(openSettings: {}, quit: {}))
            .environment(preferences)
            .environment(preview)
            .environment(timeSource)
            .environment(PanelModel())
            .preferredColorScheme(.dark)

        let hosting = NSHostingView(rootView: AnyView(root))
        hosting.sizingOptions = [.intrinsicContentSize]
        hosting.frame.size = hosting.fittingSize
        hosting.appearance = NSAppearance(named: .darkAqua)

        // The real panel is a borderless status-item surface over the popover
        // material, so reproduce that rather than a titled window.
        let visualEffect = NSVisualEffectView(frame: hosting.frame)
        visualEffect.material = .popover
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = Token.Radius.panel
        visualEffect.layer?.masksToBounds = true
        hosting.autoresizingMask = [.width, .height]
        visualEffect.addSubview(hosting)

        // The production panel is a `PanelWindow`, which is what makes a
        // borderless panel able to take key status at all.
        let window = PanelWindow(contentRect: visualEffect.bounds, styleMask: [.borderless],
                                 backing: .buffered, defer: false)
        window.contentView = visualEffect
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        return window
    }
}
#endif

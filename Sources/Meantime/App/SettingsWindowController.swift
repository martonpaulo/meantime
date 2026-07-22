import AppKit
import MeantimeKit
import SwiftUI

/// Hosts the SwiftUI settings in a plain, self-managed window. A status-bar
/// accessory app has no menu bar of its own, so it owns this window directly
/// rather than relying on the SwiftUI `Settings` scene.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let preferences: Preferences
    private let formatter: ClockFormatter
    private let updateManager: UpdateManager

    init(preferences: Preferences, formatter: ClockFormatter, updateManager: UpdateManager) {
        self.preferences = preferences
        self.formatter = formatter
        self.updateManager = updateManager
    }

    func show() {
        if window == nil { window = makeWindow() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let root = SettingsView(formatter: formatter, updateManager: updateManager)
            .environment(preferences)
        let hosting = NSHostingController(rootView: AnyView(root))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Meantime Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 480, height: 560))
        window.center()
        return window
    }
}

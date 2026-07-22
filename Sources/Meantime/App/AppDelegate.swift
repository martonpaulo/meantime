import AppKit
import MeantimeKit

/// Wires the app together and keeps the long-lived objects alive. The app is an
/// accessory (menu-bar only); there is no main window or Dock icon.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private let timeSource = TimeSource()
    private let formatter = ClockFormatter()
    private let updateManager = UpdateManager()
    private var menuBar: MenuBarController?
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let actions = PanelActions(
            openSettings: { [weak self] in self?.showSettings() },
            checkForUpdates: { [weak self] in self?.updateManager.checkForUpdates() },
            about: { [weak self] in self?.showAbout() },
            quit: { NSApp.terminate(nil) }
        )
        menuBar = MenuBarController(preferences: preferences, timeSource: timeSource,
                                    formatter: formatter, actions: actions)
    }

    private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(
                preferences: preferences, formatter: formatter, updateManager: updateManager)
        }
        settingsWindow?.show()
    }

    private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}

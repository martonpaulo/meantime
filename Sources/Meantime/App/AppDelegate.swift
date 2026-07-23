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

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Agent apps have no nib-provided menu; without one, standard key
        // equivalents (⌘W to close Settings, ⌘Q, ⌘, and text editing) don't work.
        NSApp.mainMenu = buildMainMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let actions = PanelActions(
            openSettings: { [weak self] in self?.showSettings() },
            quit: { NSApp.terminate(nil) }
        )
        menuBar = MenuBarController(preferences: preferences, timeSource: timeSource,
                                    formatter: formatter, actions: actions)
    }

    // MARK: Windows

    private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(
                preferences: preferences, formatter: formatter, updateManager: updateManager)
        }
        settingsWindow?.show()
    }

    // MARK: Main menu

    private func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Meantime",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…",
                                      action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Meantime",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Standard Edit menu so text fields (labels, emoji, custom patterns)
        // support the usual editing shortcuts.
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All",
                         action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close",
                           action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize",
                           action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        return mainMenu
    }

    @objc private func openSettingsFromMenu() {
        showSettings()
    }
}

import AppKit
import MeantimeKit
import SwiftUI

/// Wires the app together and keeps the long-lived objects alive. The app is an
/// accessory (menu-bar only); there is no main window or Dock icon.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private let timeSource = TimeSource()
    private let formatter = ClockFormatter()
    private let updateManager = UpdateManager()
    private lazy var settingsPreview = SettingsPreview(preferences: preferences)
    private lazy var clockEditingSession = ClockEditingSession(
        preferences: preferences, settingsPreview: settingsPreview)
    private var menuBar: MenuBarController?
    private var settingsWindow: SettingsWindowController?
#if DEBUG
    private var validationPanelWindow: NSWindow?
    private var screenshotOutputURL: URL? {
        guard let flag = CommandLine.arguments.firstIndex(of: "--capture-screenshots"),
              CommandLine.arguments.indices.contains(flag + 1) else { return nil }
        return URL(fileURLWithPath: CommandLine.arguments[flag + 1], isDirectory: true)
    }
#endif

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Agent apps have no nib-provided menu; without one, standard key
        // equivalents (⌘W to close Settings, ⌘Q, ⌘, and text editing) don't work.
        NSApp.mainMenu = buildMainMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
#if DEBUG
        if let outputURL = screenshotOutputURL {
            do {
                try ScreenshotCapture.captureAll(to: outputURL)
            } catch {
                fputs("screenshot capture failed: \(error)\n", stderr)
            }
            NSApp.terminate(nil)
            return
        }
        if CommandLine.arguments.contains("--diagnose-schedule-analysis") {
            let passed = ScheduleAnalysisDiagnostic.run()
            print(passed ? "ALL CHECKS PASSED" : "CHECKS FAILED")
            NSApp.terminate(nil)
            return
        }
        prepareValidationData()
#endif
        let actions = PanelActions(
            openSettings: { [weak self] in self?.showSettings() },
            quit: { NSApp.terminate(nil) }
        )
        menuBar = MenuBarController(preferences: preferences, settingsPreview: settingsPreview,
                                    timeSource: timeSource, formatter: formatter, actions: actions)
#if DEBUG
        if CommandLine.arguments.contains("--ui-validation-settings") {
            showSettings(pane: .clocks)
        } else if CommandLine.arguments.contains("--ui-validation-format") {
            showSettings(pane: .format)
        } else if CommandLine.arguments.contains("--ui-validation-general") {
            showSettings(pane: .general)
        } else if CommandLine.arguments.contains("--ui-validation-panel") {
            showValidationPanel()
        }
#endif
    }

    // MARK: Windows

    private func showSettings(pane: SettingsPane? = nil) {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(
                preferences: preferences, settingsPreview: settingsPreview,
                clockEditingSession: clockEditingSession,
                formatter: formatter, updateManager: updateManager)
        }
        settingsWindow?.show(pane: pane)
    }

    // MARK: Main menu

    private func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appMenu = NSMenu(title: String(localized: "Meantime"))
        let aboutItem = NSMenuItem(
            title: String(localized: "About Meantime"), action: #selector(openAboutFromMenu),
            keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        appMenu.addItem(.separator())
        let settingsItem = NSMenuItem(title: String(localized: "Settings…"),
                                      action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        let servicesMenu = NSMenu(title: String(localized: "Services"))
        let servicesItem = NSMenuItem(title: String(localized: "Services"), action: nil, keyEquivalent: "")
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Hide Meantime"),
                        action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(
            title: String(localized: "Hide Others"),
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: String(localized: "Show All"),
                        action: #selector(NSApplication.unhideAllApplications(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Quit Meantime"),
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appMenuItem = NSMenuItem(title: String(localized: "Meantime"), action: nil, keyEquivalent: "")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Standard Edit menu so text fields (labels, emoji, custom patterns)
        // support the usual editing shortcuts.
        let editMenu = NSMenu(title: String(localized: "Edit"))
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All",
                         action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editMenuItem = NSMenuItem(title: String(localized: "Edit"), action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let windowMenu = NSMenu(title: String(localized: "Window"))
        windowMenu.addItem(withTitle: "Close",
                           action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize",
                           action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom",
                           action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        let windowMenuItem = NSMenuItem(title: String(localized: "Window"), action: nil, keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        let helpMenu = NSMenu(title: String(localized: "Help"))
        helpMenu.addItem(menuItem(
            title: "Meantime Help", action: #selector(openWebsiteFromMenu),
            keyEquivalent: "?"))
        helpMenu.addItem(menuItem(
            title: "Date Format Guide", action: #selector(openFormatGuideFromMenu)))
        helpMenu.addItem(.separator())
        helpMenu.addItem(menuItem(
            title: "Report an Issue…", action: #selector(openIssueReporterFromMenu)))
        let helpMenuItem = NSMenuItem(title: String(localized: "Help"), action: nil, keyEquivalent: "")
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)
        NSApp.helpMenu = helpMenu

        return mainMenu
    }

    private func menuItem(title: String, action: Selector,
                          keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func openSettingsFromMenu() {
        showSettings()
    }

    @objc private func openAboutFromMenu() {
        showSettings(pane: .about)
    }

    @objc private func openWebsiteFromMenu() {
        open("https://martonpaulo.com/meantime/")
    }

    @objc private func openFormatGuideFromMenu() {
        open("https://martonpaulo.com/meantime/format.html")
    }

    @objc private func openIssueReporterFromMenu() {
        open("https://github.com/martonpaulo/meantime/issues")
    }

    private func open(_ address: String) {
        guard let url = URL(string: address) else { return }
        NSWorkspace.shared.open(url)
    }

#if DEBUG
    private func prepareValidationData() {
        if CommandLine.arguments.contains("--ui-validation-screenshot-data") {
            preferences.clocks = [
                WorldClock(timeZoneID: "America/New_York", customLabel: "New York"),
                WorldClock(timeZoneID: "America/Recife", customLabel: "Recife"),
            ]
            preferences.menuBarLayout = .individual
        } else if CommandLine.arguments.contains("--ui-validation-many-clocks") {
            let identifiers = Array(TimeZone.knownTimeZoneIdentifiers.prefix(50))
            preferences.clocks = identifiers.enumerated().map { index, identifier in
                WorldClock(timeZoneID: identifier, customLabel: "Clock \(index + 1)")
            }
        } else if CommandLine.arguments.contains("--ui-validation-many-windows") {
            var clock = WorldClock(timeZoneID: "UTC", customLabel: "Schedule Stress Test")
            clock.activeWindows = (0..<20).map { hour in
                ActiveWindow(startMinute: hour * 60, endMinute: (hour + 1) * 60)
            }
            preferences.clocks = [clock]
        }
    }

    /// Debug-only visual harness. It renders the production panel tree without
    /// relying on status-item coordinates, keeping retained UI checks stable.
    private func showValidationPanel() {
        let model = PanelModel()
        if CommandLine.arguments.contains("--ui-validation-travel") {
            model.selectedDay = Calendar.current.date(
                byAdding: .day, value: 30, to: timeSource.now)
            model.selectedTime = Calendar.current.date(
                bySettingHour: 10, minute: 36, second: 0, of: timeSource.now)
        }
        var root = AnyView(PanelView(
            formatter: formatter,
            actions: PanelActions(openSettings: {}, quit: {}))
            .environment(preferences)
            .environment(settingsPreview)
            .environment(timeSource)
            .environment(model))
        if CommandLine.arguments.contains("--ui-validation-light") {
            root = AnyView(root.preferredColorScheme(.light))
        }
        if CommandLine.arguments.contains("--ui-validation-rtl") {
            root = AnyView(root.environment(\.layoutDirection, .rightToLeft))
        }
        if CommandLine.arguments.contains("--ui-validation-large-text") {
            root = AnyView(root.environment(\.dynamicTypeSize, .accessibility2))
        }
        let hosting = NSHostingController(rootView: root)
        let panelWindow = NSWindow(contentViewController: hosting)
        panelWindow.styleMask = [.borderless]
        panelWindow.isOpaque = false
        panelWindow.backgroundColor = .clear
        panelWindow.hasShadow = true
        panelWindow.isReleasedWhenClosed = false
        panelWindow.center()
        validationPanelWindow = panelWindow
        NSApp.activate()
        panelWindow.makeKeyAndOrderFront(nil)
    }
#endif
}

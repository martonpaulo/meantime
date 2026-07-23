import AppKit
import MeantimeKit
import SwiftUI

/// The Settings window: a native toolbar-style NSTabViewController (the classic
/// System Settings pane look) hosting SwiftUI panes. ⌘W closes it through the
/// app's Window menu; the selected pane persists across launches.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let preferences: Preferences
    private let settingsPreview: SettingsPreview
    private let formatter: ClockFormatter
    private let updateManager: UpdateManager

    init(preferences: Preferences, settingsPreview: SettingsPreview,
         formatter: ClockFormatter, updateManager: UpdateManager) {
        self.preferences = preferences
        self.settingsPreview = settingsPreview
        self.formatter = formatter
        self.updateManager = updateManager
        super.init()
    }

    func show() {
        if window == nil {
            let tabs = SettingsTabViewController(preferences: preferences,
                                                 settingsPreview: settingsPreview,
                                                 formatter: formatter,
                                                 updateManager: updateManager)
            let newWindow = NSWindow(contentViewController: tabs)
            newWindow.styleMask = [.titled, .closable, .miniaturizable]
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self
            newWindow.center()
            window = newWindow
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard settingsPreview.hasAppearanceChanges else {
            settingsPreview.discardAppearance()
            return true
        }
        confirmUnsavedAppearance(in: sender, settingsPreview: settingsPreview) { shouldLeave in
            if shouldLeave { sender.performClose(nil) }
        }
        return false
    }
}

/// Toolbar-style panes with SF Symbols; pane switches are instant (Reduce
/// Motion friendly) and the selection is remembered.
private final class SettingsTabViewController: NSTabViewController {
    private static let selectedPaneKey = "settingsSelectedPane"

    private let settingsPreview: SettingsPreview

    init(preferences: Preferences, settingsPreview: SettingsPreview,
         formatter: ClockFormatter, updateManager: UpdateManager) {
        self.settingsPreview = settingsPreview
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
        transitionOptions = []
        addPane(title: "Clocks", symbol: "globe",
                view: ClocksPane()
                    .environment(preferences).environment(settingsPreview))
        addPane(title: "Format", symbol: "textformat",
                view: FormatPane(formatter: formatter)
                    .environment(preferences).environment(settingsPreview))
        addPane(title: "General", symbol: "gearshape",
                view: GeneralPane(updateManager: updateManager).environment(preferences))
        addPane(title: "About", symbol: "info.circle", view: AboutPane())
        let saved = UserDefaults.standard.integer(forKey: Self.selectedPaneKey)
        if saved >= 0, saved < tabViewItems.count {
            selectedTabViewItemIndex = saved
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func addPane(title: String, symbol: String, view: some View) {
        let hosting = NSHostingController(rootView: AnyView(view))
        hosting.title = title
        hosting.sizingOptions = .preferredContentSize
        let item = NSTabViewItem(viewController: hosting)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        addTabViewItem(item)
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        UserDefaults.standard.set(selectedTabViewItemIndex, forKey: Self.selectedPaneKey)
    }

    override func tabView(_ tabView: NSTabView,
                          shouldSelect tabViewItem: NSTabViewItem?) -> Bool {
        guard super.tabView(tabView, shouldSelect: tabViewItem) else { return false }
        guard tabView.selectedTabViewItem?.label == "Format",
              tabViewItem !== tabView.selectedTabViewItem else { return true }
        guard settingsPreview.hasAppearanceChanges else {
            settingsPreview.discardAppearance()
            return true
        }
        guard let tabViewItem, let window = view.window else { return true }

        confirmUnsavedAppearance(in: window, settingsPreview: settingsPreview) { shouldLeave in
            if shouldLeave { tabView.selectTabViewItem(tabViewItem) }
        }
        return false
    }
}

/// Native Save / Discard / Cancel prompt shared by tab changes and window
/// closing. Save is unavailable while a custom pattern is structurally invalid.
@MainActor
private func confirmUnsavedAppearance(in window: NSWindow, settingsPreview: SettingsPreview,
                                      completion: @escaping (Bool) -> Void) {
    let alert = NSAlert()
    alert.messageText = "Save changes to Format?"
    alert.informativeText = "Your preview has unsaved changes."
    let save = alert.addButton(withTitle: "Save")
    save.keyEquivalent = "\r"
    save.isEnabled = settingsPreview.canSaveAppearance
    alert.addButton(withTitle: "Discard Changes")
    alert.addButton(withTitle: "Cancel")

    alert.beginSheetModal(for: window) { response in
        switch response {
        case .alertFirstButtonReturn:
            settingsPreview.saveAppearance()
            completion(true)
        case .alertSecondButtonReturn:
            settingsPreview.discardAppearance()
            completion(true)
        default:
            completion(false)
        }
    }
}

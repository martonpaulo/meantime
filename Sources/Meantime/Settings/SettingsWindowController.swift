import AppKit
import MeantimeKit
import SwiftUI

/// The Settings window: a native toolbar-style NSTabViewController (the classic
/// System Settings pane look) hosting SwiftUI panes. ⌘W closes it through the
/// app's Window menu; the selected pane persists across launches.
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
        if window == nil {
            let tabs = SettingsTabViewController(preferences: preferences,
                                                 formatter: formatter,
                                                 updateManager: updateManager)
            let newWindow = NSWindow(contentViewController: tabs)
            newWindow.styleMask = [.titled, .closable, .miniaturizable]
            newWindow.isReleasedWhenClosed = false
            newWindow.center()
            window = newWindow
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

/// Toolbar-style panes with SF Symbols; pane switches are instant (Reduce
/// Motion friendly) and the selection is remembered.
private final class SettingsTabViewController: NSTabViewController {
    private static let selectedPaneKey = "settingsSelectedPane"

    init(preferences: Preferences, formatter: ClockFormatter, updateManager: UpdateManager) {
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
        transitionOptions = []
        addPane(title: "Clocks", symbol: "globe",
                view: ClocksPane(formatter: formatter).environment(preferences))
        addPane(title: "Format", symbol: "textformat",
                view: FormatPane(formatter: formatter).environment(preferences))
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
}

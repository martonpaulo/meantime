import AppKit
import MeantimeKit
import SwiftUI

enum SettingsPane: Int {
    case clocks
    case format
    case general
    case about
}

/// The Settings window: a native toolbar-style NSTabViewController (the classic
/// System Settings pane look) hosting SwiftUI panes. ⌘W closes it through the
/// app's Window menu; the selected pane persists across launches.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    /// The Save / Discard / Cancel prompts. Injectable so the termination
    /// fixture can answer them; the app always uses the native sheets.
    var confirmations: DraftConfirmations = .native
    private var isResolvingPendingDrafts = false

    private var window: NSWindow?
    private var tabs: SettingsTabViewController?
    private let preferences: Preferences
    private let settingsPreview: SettingsPreview
    private let clockEditingSession: ClockEditingSession
    private let formatter: ClockFormatter
    private let updateManager: UpdateManager

    init(preferences: Preferences, settingsPreview: SettingsPreview,
         clockEditingSession: ClockEditingSession,
         formatter: ClockFormatter, updateManager: UpdateManager) {
        self.preferences = preferences
        self.settingsPreview = settingsPreview
        self.clockEditingSession = clockEditingSession
        self.formatter = formatter
        self.updateManager = updateManager
        super.init()
    }

#if DEBUG
    /// Debug-only: gives the termination fixture a window to host prompts on,
    /// without going through `show()` and its reopening discard path.
    func attachForTesting(window: NSWindow) {
        self.window = window
    }
#endif

    /// True when quitting or closing now would silently drop a draft.
    var hasPendingDrafts: Bool {
        clockEditingSession.hasUnsavedChanges || settingsPreview.hasAppearanceChanges
    }

    /// Resolves every pending draft through the same prompts a window close or
    /// pane switch uses, then reports whether leaving may proceed.
    ///
    /// Clock drafts are resolved first, appearance second. A Save accepted for
    /// the first is a real saved action even if the second is cancelled: this is
    /// not an atomic multi-draft transaction, and pretending otherwise would
    /// mean undoing something the user explicitly asked for.
    func resolvePendingDrafts(completion: @escaping (Bool) -> Void) {
        // Repeated Quit while a sheet is up must not stack a second prompt.
        guard !isResolvingPendingDrafts else { completion(false); return }
        guard let window else { completion(true); return }
        isResolvingPendingDrafts = true

        // Bring the window forward directly: `show()` would take the reopening
        // path, which discards exactly the clock draft we are asking about.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)

        resolveClockDraft(in: window) { [weak self] proceed in
            guard let self else { return }
            guard proceed else { finishResolving(false, completion); return }
            resolveAppearanceDraft(in: window) { [weak self] proceed in
                self?.finishResolving(proceed, completion)
            }
        }
    }

    private func resolveClockDraft(in window: NSWindow, completion: @escaping (Bool) -> Void) {
        guard clockEditingSession.hasUnsavedChanges else { completion(true); return }
        confirmations.clock(window, clockEditingSession) { [weak self] shouldLeave in
            guard let self else { return completion(false) }
            // Postcondition: a Save that did not actually clear the draft (an
            // invalid one) must not be treated as permission to leave.
            completion(shouldLeave && !clockEditingSession.hasUnsavedChanges)
        }
    }

    private func resolveAppearanceDraft(in window: NSWindow, completion: @escaping (Bool) -> Void) {
        guard settingsPreview.hasAppearanceChanges else { completion(true); return }
        confirmations.appearance(window, settingsPreview) { [weak self] shouldLeave in
            guard let self else { return completion(false) }
            completion(shouldLeave && !settingsPreview.hasAppearanceChanges)
        }
    }

    private func finishResolving(_ proceed: Bool, _ completion: @escaping (Bool) -> Void) {
        isResolvingPendingDrafts = false
        completion(proceed)
    }

    func show(pane: SettingsPane? = nil) {
        let firstShow = window == nil
        if window == nil {
            let tabs = SettingsTabViewController(preferences: preferences,
                                                 settingsPreview: settingsPreview,
                                                 clockEditingSession: clockEditingSession,
                                                 formatter: formatter,
                                                 updateManager: updateManager)
            let newWindow = NSWindow(contentViewController: tabs)
            newWindow.styleMask = [.titled, .closable, .miniaturizable]
            newWindow.title = "Meantime Settings"
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self
            newWindow.center()
            self.tabs = tabs
            window = newWindow
        }
        // Reopening a closed window returns to the Clocks list rather than resuming a
        // half-finished edit. An already-visible window (re-triggered ⌘,) is left alone.
        if !firstShow, window?.isVisible == false {
            clockEditingSession.discardForExternalNavigation()
        }
        if let pane { tabs?.select(pane) }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if clockEditingSession.hasUnsavedChanges {
            confirmations.clock(sender, clockEditingSession) { shouldLeave in
                if shouldLeave { sender.performClose(nil) }
            }
            return false
        }
        if clockEditingSession.isActive {
            clockEditingSession.discardForExternalNavigation()
        }
        guard settingsPreview.hasAppearanceChanges else {
            settingsPreview.discardAppearance()
            return true
        }
        confirmations.appearance(sender, settingsPreview) { shouldLeave in
            if shouldLeave { sender.performClose(nil) }
        }
        return false
    }
}

/// Toolbar-style panes with SF Symbols; pane switches are instant (Reduce
/// Motion friendly) and the selection is remembered.
final class SettingsTabViewController: NSTabViewController {
    private static let selectedPaneKey = "settingsSelectedPane"

    private let settingsPreview: SettingsPreview
    private let clockEditingSession: ClockEditingSession
    var confirmations: DraftConfirmations = .native

    init(preferences: Preferences, settingsPreview: SettingsPreview,
         clockEditingSession: ClockEditingSession,
         formatter: ClockFormatter, updateManager: UpdateManager) {
        self.settingsPreview = settingsPreview
        self.clockEditingSession = clockEditingSession
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
        transitionOptions = []
        addPane(title: "Clocks", symbol: "globe",
                view: ClocksPane(formatter: formatter)
                    .environment(preferences)
                    .environment(settingsPreview)
                    .environment(clockEditingSession))
        addPane(title: "Format", symbol: "textformat",
                view: FormatPane()
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

    func select(_ pane: SettingsPane) {
        selectedTabViewItemIndex = pane.rawValue
    }

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
        // Panes are retained, so a pane returning to view gets no SwiftUI
        // appearance callback. One notification lets a pane re-read state it
        // does not own (system login-item consent) without polling for it.
        NotificationCenter.default.post(name: .settingsPaneDidAppear, object: nil)
        UserDefaults.standard.set(selectedTabViewItemIndex, forKey: Self.selectedPaneKey)
    }

    override func tabView(_ tabView: NSTabView,
                          shouldSelect tabViewItem: NSTabViewItem?) -> Bool {
        guard super.tabView(tabView, shouldSelect: tabViewItem) else { return false }
        guard let tabViewItem, tabViewItem !== tabView.selectedTabViewItem else { return true }
        if tabView.selectedTabViewItem?.label == "Clocks",
           clockEditingSession.hasUnsavedChanges,
           let window = view.window {
            confirmations.clock(window, clockEditingSession) { shouldLeave in
                if shouldLeave { tabView.selectTabViewItem(tabViewItem) }
            }
            return false
        }
        if tabView.selectedTabViewItem?.label == "Clocks",
           clockEditingSession.isActive {
            clockEditingSession.discardForExternalNavigation()
        }
        guard tabView.selectedTabViewItem?.label == "Format",
              tabViewItem !== tabView.selectedTabViewItem else { return true }
        guard settingsPreview.hasAppearanceChanges else {
            settingsPreview.discardAppearance()
            return true
        }
        guard let window = view.window else { return true }

        confirmations.appearance(window, settingsPreview) { shouldLeave in
            if shouldLeave { tabView.selectTabViewItem(tabViewItem) }
        }
        return false
    }
}

/// Native Save / Discard / Cancel prompt shared by tab changes and window
/// closing. Save is unavailable while a custom pattern is structurally invalid.
@MainActor
func confirmUnsavedAppearance(in window: NSWindow, settingsPreview: SettingsPreview,
                                      completion: @escaping (Bool) -> Void) {
    let alert = NSAlert()
    alert.messageText = "Save changes to Format?"
    alert.informativeText = "The menu bar is showing changes that have not been saved."
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

/// Native Save / Discard / Cancel prompt for the inline clock editor.
@MainActor
func confirmUnsavedClock(in window: NSWindow, session: ClockEditingSession,
                                 completion: @escaping (Bool) -> Void) {
    let alert = NSAlert()
    alert.messageText = session.draft?.isNew == true
        ? "Add this clock before leaving?"
        : "Save changes to this clock?"
    alert.informativeText = "Changes are visible in the menu bar until you save or discard them."
    let save = alert.addButton(withTitle: session.draft?.isNew == true ? "Add Clock" : "Save")
    save.keyEquivalent = "\r"
    save.isEnabled = session.canSave
    alert.addButton(withTitle: session.draft?.isNew == true ? "Discard New Clock" : "Discard Changes")
    alert.addButton(withTitle: "Cancel")

    alert.beginSheetModal(for: window) { response in
        switch response {
        case .alertFirstButtonReturn:
            completion(session.save())
        case .alertSecondButtonReturn:
            session.discardForExternalNavigation()
            completion(true)
        default:
            completion(false)
        }
    }
}

/// The Save / Discard / Cancel prompts, as functions, so every entrypoint that
/// can lose a draft shares one behavior and a fixture can answer them without a
/// person clicking a sheet.
@MainActor
struct DraftConfirmations {
    var clock: (NSWindow, ClockEditingSession, @escaping (Bool) -> Void) -> Void
    var appearance: (NSWindow, SettingsPreview, @escaping (Bool) -> Void) -> Void

    static let native = DraftConfirmations(
        clock: { confirmUnsavedClock(in: $0, session: $1, completion: $2) },
        appearance: { confirmUnsavedAppearance(in: $0, settingsPreview: $1, completion: $2) })
}

extension Notification.Name {
    /// Posted when a Settings pane becomes the selected one, including a return
    /// to a pane the tab controller kept alive.
    static let settingsPaneDidAppear = Notification.Name("meantime.settingsPaneDidAppear")
}

import AppKit
import MeantimeKit
import Observation
import SwiftUI

/// Owns the menu-bar surface: one status item per pinned clock (or a single
/// fallback item when none are pinned), the shared panel popover, and the
/// boundary-aligned ticker that refreshes both without ever spinning idly.
@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let preferences: Preferences
    private let timeSource: TimeSource
    private let formatter: ClockFormatter
    private let panelModel = PanelModel()
    private let ticker = ClockTicker()
    private let popover = NSPopover()

    private var entries: [(item: NSStatusItem, clockID: UUID?)] = []
    private var statusSignature = ""

    init(preferences: Preferences, timeSource: TimeSource,
         formatter: ClockFormatter, actions: PanelActions) {
        self.preferences = preferences
        self.timeSource = timeSource
        self.formatter = formatter
        super.init()

        configurePopover(actions: actions)

        ticker.onTick = { [weak self] in self?.handleTick() }
        ticker.visibleProvider = { [weak self] in self?.currentVisible() ?? [] }

        rebuildStatusItems()
        observePreferences()
        ticker.refresh()
    }

    // MARK: Ticking

    private func handleTick() {
        timeSource.advance()   // drives the SwiftUI panel
        refreshStatusTitles()  // drives the AppKit items
    }

    /// Every visible contribution to the update cadence. Empty ⇒ no timer runs.
    private func currentVisible() -> [ClockUpdatePlanner.Visible] {
        var visible: [ClockUpdatePlanner.Visible] = []
        for clock in preferences.clocks where clock.isPinned {
            let granularity = TimeGranularity.finest(renderMode: clock.renderMode, format: preferences.timeFormat)
            visible.append(.init(granularity: granularity, timeZone: clock.timeZone))
        }
        if popover.isShown {
            let panelGranularity = TimeGranularity.finest(renderMode: .timeOnly, format: preferences.timeFormat)
            for clock in preferences.clocks {
                visible.append(.init(granularity: panelGranularity, timeZone: clock.timeZone))
            }
        }
        return visible
    }

    // MARK: Status items

    private func rebuildStatusItems() {
        for entry in entries { NSStatusBar.system.removeStatusItem(entry.item) }
        entries.removeAll()

        let pinned = preferences.clocks.filter(\.isPinned)
        if pinned.isEmpty {
            entries.append((makeStatusItem(), nil)) // always reachable
        } else {
            for clock in pinned { entries.append((makeStatusItem(), clock.id)) }
        }
        statusSignature = signature(of: pinned)
        refreshStatusTitles()
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        return item
    }

    private func refreshStatusTitles() {
        let now = timeSource.now
        for entry in entries {
            guard let button = entry.item.button else { continue }
            if let id = entry.clockID, let clock = preferences.clocks.first(where: { $0.id == id }) {
                apply(clock, to: button, now: now)
            } else {
                applyFallback(to: button)
            }
        }
    }

    private func apply(_ clock: WorldClock, to button: NSStatusBarButton, now: Date) {
        let time = formatter.string(for: now, clock: clock, format: preferences.timeFormat)
        switch clock.renderMode {
        case .analogClock:
            button.image = AnalogClockRenderer.image(for: now, timeZone: clock.timeZone,
                                                      pointSize: Token.Size.analogClock)
            button.imagePosition = .imageOnly
            button.attributedTitle = NSAttributedString(string: "")
        case .timeOnly:
            button.image = nil
            button.imagePosition = .noImage
            button.attributedTitle = StatusItemTitle.attributed(
                emoji: nil, time: time, textSize: preferences.textSize, spacing: preferences.elementSpacing)
        case .flagAndTime:
            button.image = nil
            button.imagePosition = .noImage
            button.attributedTitle = StatusItemTitle.attributed(
                emoji: clock.displayEmoji, time: time,
                textSize: preferences.textSize, spacing: preferences.elementSpacing)
        }
        button.toolTip = "\(clock.displayLabel) — \(time)"
        button.setAccessibilityLabel("\(clock.displayLabel), \(time)")
    }

    private func applyFallback(to button: NSStatusBarButton) {
        button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Meantime")
        button.image?.isTemplate = true
        button.imagePosition = .imageOnly
        button.attributedTitle = NSAttributedString(string: "")
        button.toolTip = "Meantime"
        button.setAccessibilityLabel("Meantime")
    }

    private func signature(of pinned: [WorldClock]) -> String {
        pinned.isEmpty ? "fallback" : pinned.map(\.id.uuidString).joined(separator: ",")
    }

    // MARK: Popover

    private func configurePopover(actions: PanelActions) {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let root = PanelView(formatter: formatter, actions: actions)
            .environment(preferences)
            .environment(timeSource)
            .environment(panelModel)
        popover.contentViewController = NSHostingController(rootView: AnyView(root))
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        panelModel.reset()
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        ticker.refresh() // panel open ⇒ finer cadence
    }

    func popoverDidClose(_ notification: Notification) {
        ticker.refresh() // panel closed ⇒ relax cadence
    }

    // MARK: Observation

    /// Reacts to preference changes: rebuild items only when the pinned set
    /// changes (avoids flicker while dragging a slider); otherwise just refresh.
    private func observePreferences() {
        withObservationTracking {
            _ = preferences.clocks
            _ = preferences.timeFormat
            _ = preferences.textSize
            _ = preferences.elementSpacing
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.syncFromPreferences()
                self.observePreferences()
            }
        }
    }

    private func syncFromPreferences() {
        if signature(of: preferences.clocks.filter(\.isPinned)) != statusSignature {
            rebuildStatusItems()
        } else {
            refreshStatusTitles()
        }
        ticker.refresh()
    }
}

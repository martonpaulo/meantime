import AppKit
import MeantimeKit
import Observation
import SwiftUI

/// Owns the menu-bar surface: status items for the currently *shown* clocks
/// (pinned, and inside their scheduled hours), in either individual or combined
/// layout; the anchored panel; and the boundary-aligned ticker that
/// refreshes everything without ever spinning idly.
@MainActor
final class MenuBarController: NSObject {
    private let preferences: Preferences
    private let settingsPreview: SettingsPreview
    private let timeSource: TimeSource
    private let formatter: ClockFormatter
    private let panelModel = PanelModel()
    private let ticker = ClockTicker()
    private let panel: PanelController

    private var entries: [(item: NSStatusItem, clockID: UUID?)] = []
    private var shownSignature = ""

    init(preferences: Preferences, settingsPreview: SettingsPreview, timeSource: TimeSource,
         formatter: ClockFormatter, actions: PanelActions) {
        self.preferences = preferences
        self.settingsPreview = settingsPreview
        self.timeSource = timeSource
        self.formatter = formatter

        let root = PanelView(formatter: formatter, actions: actions)
            .environment(preferences)
            .environment(settingsPreview)
            .environment(timeSource)
            .environment(panelModel)
        panel = PanelController(content: AnyView(root))

        super.init()

        panel.onVisibilityChange = { [weak self] shown in
            if shown { self?.panelModel.reset() }
            self?.ticker.refresh() // panel open ⇒ finer cadence; closed ⇒ relax
        }
        ticker.onTick = { [weak self] in self?.handleTick() }
        ticker.planProvider = { [weak self] in self?.plan() ?? (visible: [], transitions: []) }

        observePreferences()
        ticker.refresh() // first paint + arm
    }

    // MARK: Ticking

    private func handleTick() {
        timeSource.advance()  // drives the SwiftUI panel
        syncItems()           // drives the AppKit items (and scheduled hide/show)
    }

    /// The wake plan: granularity of everything visible, plus the next
    /// scheduled-visibility transition of any pinned clock.
    private func plan() -> (visible: [ClockUpdatePlanner.Visible], transitions: [Date]) {
        let now = Date()
        var visible: [ClockUpdatePlanner.Visible] = []

        for clock in shownClocks(at: now) {
            let mode = settingsPreview.menuBarLayout == .combined ? textualMode(for: clock) : clock.renderMode
            visible.append(.init(
                granularity: TimeGranularity.finest(renderMode: mode, format: settingsPreview.timeFormat),
                timeZone: clock.timeZone))
        }
        if panel.isShown {
            // Panel rows always show complete time, even for hour-only bars.
            let panelGranularity = TimeGranularity.finest(
                renderMode: .timeOnly,
                format: PanelRowFormatter.effectiveFormat(settingsPreview.timeFormat))
            for clock in settingsPreview.clocks {
                visible.append(.init(granularity: panelGranularity, timeZone: clock.timeZone))
            }
        }
        let transitions = settingsPreview.clocks.compactMap { clock -> Date? in
            guard clock.isPinned else { return nil }
            return ClockSchedule.nextTransition(after: now, windows: clock.activeWindows,
                                                timeZone: clock.timeZone)
        }
        return (visible, transitions)
    }

    // MARK: Shown clocks

    private func shownClocks(at date: Date) -> [WorldClock] {
        settingsPreview.clocks.filter { $0.isActiveInMenuBar(at: date) }
    }

    /// The combined item is a single text run; an analog-face clock contributes
    /// its textual form there (adornment + time) since a glyph cannot ride along.
    private func textualMode(for clock: WorldClock) -> ClockRenderMode {
        clock.renderMode == .analogClock ? .flagAndTime : clock.renderMode
    }

    private func signature(shown: [WorldClock]) -> String {
        let ids = shown.map(\.id.uuidString).joined(separator: ",")
        return "\(settingsPreview.menuBarLayout.rawValue)|\(ids)"
    }

    // MARK: Status items

    /// Rebuilds items only when the shown set or layout changes; otherwise just
    /// refreshes titles, so a slider drag never flickers the menu bar.
    private func syncItems() {
        let shown = shownClocks(at: timeSource.now)
        let newSignature = signature(shown: shown)
        if newSignature != shownSignature {
            rebuildStatusItems(shown: shown)
            shownSignature = newSignature
        }
        refreshStatusTitles(shown: shown)
    }

    private func rebuildStatusItems(shown: [WorldClock]) {
        for entry in entries { NSStatusBar.system.removeStatusItem(entry.item) }
        entries.removeAll()

        switch (shown.isEmpty, settingsPreview.menuBarLayout) {
        case (true, _):
            entries.append((makeStatusItem(), nil)) // always reachable
        case (false, .combined):
            entries.append((makeStatusItem(), nil))
        case (false, .individual):
            for clock in shown { entries.append((makeStatusItem(), clock.id)) }
        }
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        return item
    }

    private func refreshStatusTitles(shown: [WorldClock]) {
        let now = timeSource.now
        for entry in entries {
            guard let button = entry.item.button else { continue }
            if let id = entry.clockID, let clock = shown.first(where: { $0.id == id }) {
                apply(clock, to: button, now: now)
            } else if !shown.isEmpty, settingsPreview.menuBarLayout == .combined {
                applyCombined(shown, to: button, now: now)
            } else {
                applyFallback(to: button)
            }
            constrain(entry.item, button: button)
        }
    }

    private func constrain(_ item: NSStatusItem, button: NSStatusBarButton) {
        guard button.imagePosition != .imageOnly else {
            item.length = NSStatusItem.squareLength
            return
        }
        button.cell?.lineBreakMode = .byTruncatingTail
        let desiredWidth = button.attributedTitle.size().width + Token.Space.lg
        item.length = min(max(desiredWidth, Token.Size.hitTarget),
                          Token.Size.statusItemMaxWidth)
    }

    private func apply(_ clock: WorldClock, to button: NSStatusBarButton, now: Date) {
        let time = formatter.string(for: now, clock: clock, format: settingsPreview.timeFormat)
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
                adornment: nil, time: time, textSize: settingsPreview.textSize,
                spacing: settingsPreview.elementSpacing)
        case .flagAndTime:
            button.image = nil
            button.imagePosition = .noImage
            button.attributedTitle = StatusItemTitle.attributed(
                adornment: clock.displayAdornment, time: time,
                textSize: settingsPreview.textSize, spacing: settingsPreview.elementSpacing)
        }
        button.toolTip = "\(clock.displayLabel): \(time)"
        button.setAccessibilityLabel("\(clock.displayLabel), \(time)")
    }

    private func applyCombined(_ shown: [WorldClock], to button: NSStatusBarButton, now: Date) {
        let entries = shown.map { clock -> (adornment: String?, time: String) in
            let time = formatter.string(for: now, clock: clock, format: settingsPreview.timeFormat)
            return (textualMode(for: clock) == .timeOnly ? nil : clock.displayAdornment, time)
        }
        button.image = nil
        button.imagePosition = .noImage
        button.attributedTitle = StatusItemTitle.combined(
            entries: entries, separator: settingsPreview.combinedSeparator,
            textSize: settingsPreview.textSize, spacing: settingsPreview.elementSpacing)
        let summary = shown.map { "\($0.displayLabel) \(formatter.string(for: now, clock: $0, format: settingsPreview.timeFormat))" }
            .joined(separator: ", ")
        button.toolTip = summary
        button.setAccessibilityLabel(summary)
    }

    private func applyFallback(to button: NSStatusBarButton) {
        button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Meantime")
        button.image?.isTemplate = true
        button.imagePosition = .imageOnly
        button.attributedTitle = NSAttributedString(string: "")
        button.toolTip = "Meantime"
        button.setAccessibilityLabel("Meantime")
    }

    // MARK: Panel

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        panel.toggle(from: sender)
    }

    // MARK: Observation

    private func observePreferences() {
        withObservationTracking {
            _ = preferences.clocks
            _ = preferences.timeFormat
            _ = preferences.menuBarLayout
            _ = preferences.textSize
            _ = preferences.elementSpacing
            _ = preferences.combinedSeparator
            _ = settingsPreview.clocks
            _ = settingsPreview.timeFormat
            _ = settingsPreview.menuBarLayout
            _ = settingsPreview.combinedSeparator
            _ = settingsPreview.textSize
            _ = settingsPreview.elementSpacing
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.syncItems()
                self.ticker.refresh()
                self.observePreferences()
            }
        }
    }
}

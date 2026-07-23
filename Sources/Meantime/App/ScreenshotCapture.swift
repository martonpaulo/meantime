#if DEBUG
import AppKit
import MeantimeKit
import SwiftUI

/// Deterministic, offscreen documentation capture. No window is ordered front,
/// no status item is installed, and no Screen Recording or Accessibility
/// permission is needed.
@MainActor
enum ScreenshotCapture {
    private static let scale: CGFloat = 2
    private static let exampleDate = ISO8601DateFormatter().date(
        from: "2026-07-23T15:11:00Z")!

    static func captureAll(to directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)

        let store = EphemeralPreferenceStore()
        let preferences = Preferences(store: store)
        preferences.clocks = [
            WorldClock(timeZoneID: "America/Recife", customLabel: "Recife"),
            WorldClock(timeZoneID: "Europe/Madrid", customLabel: "Madrid"),
        ]
        preferences.menuBarLayout = .individual

        let formatter = ClockFormatter()
        let preview = SettingsPreview(preferences: preferences)
        let editing = ClockEditingSession(preferences: preferences, settingsPreview: preview)
        let timeSource = TimeSource(now: exampleDate)
        let panelModel = PanelModel()

        let panel = PanelView(
            formatter: formatter,
            actions: PanelActions(openSettings: {}, quit: {}))
            .environment(preferences)
            .environment(preview)
            .environment(timeSource)
            .environment(panelModel)
            .preferredColorScheme(.dark)
        try renderHostingView(panel, to: directory.appendingPathComponent("panel.png"))

        let statusTitle = StatusItemTitle.combined(
            entries: preferences.clocks.map { clock in
                (clock.displayAdornment,
                 formatter.string(for: exampleDate, clock: clock, format: preferences.timeFormat))
            },
            separator: preferences.combinedSeparator,
            textSize: preferences.textSize,
            spacing: preferences.elementSpacing)
        try renderMenuBar(title: statusTitle,
                          to: directory.appendingPathComponent("menu-bar.png"))

        // Render each Settings pane in a plain titled window. A window gives the native
        // List/Form the context they need to lay out, while dropping the tab-style toolbar
        // whose vibrant selection offscreen cacheDisplay cannot composite (it comes out as a
        // solid white block). Documentation capture must stay offscreen.
        func renderPane(_ view: some View, to name: String) throws {
            try renderPaneWindow(view, to: directory.appendingPathComponent(name))
        }
        try renderPane(ClocksPane(formatter: formatter)
            .environment(preferences).environment(preview).environment(editing),
            to: "settings-clocks.png")
        try renderPane(FormatPane()
            .environment(preferences).environment(preview),
            to: "settings-format.png")
        try renderPane(GeneralPane(updateManager: UpdateManager())
            .environment(preferences),
            to: "settings-general.png")
    }

    private static func renderPaneWindow(_ view: some View, to destination: URL) throws {
        let hosting = NSHostingController(rootView: AnyView(view.preferredColorScheme(.dark)))
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.title = "Meantime Settings"
        window.appearance = NSAppearance(named: .darkAqua)
        // Size the window content to the pane exactly, so there is no centering gap.
        window.setContentSize(NSSize(width: Token.Size.paneWidth, height: Token.Size.paneHeight))
        window.contentView?.layoutSubtreeIfNeeded()
        guard let frameView = window.contentView?.superview else {
            throw CaptureError.missingWindowFrame
        }
        frameView.layoutSubtreeIfNeeded()
        try writePNG(of: frameView, to: destination)
    }

    private static func renderHostingView<Content: View>(
        _ content: Content, to destination: URL
    ) throws {
        let hosting = NSHostingView(rootView: content)
        hosting.sizingOptions = [.intrinsicContentSize]
        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.frame.size = hosting.fittingSize
        hosting.layoutSubtreeIfNeeded()
        try writePNG(of: hosting, to: destination)
    }

    private static func renderMenuBar(title: NSAttributedString, to destination: URL) throws {
        let height: CGFloat = 30
        let width = max(220, ceil(title.size().width + Token.Space.xl))
        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        effect.material = .menu
        effect.blendingMode = .withinWindow
        effect.state = .active
        effect.appearance = NSAppearance(named: .darkAqua)

        let label = NSTextField(labelWithAttributedString: title)
        label.frame.size = label.fittingSize
        label.frame.origin = NSPoint(
            x: Token.Space.md,
            y: floor((height - label.frame.height) / 2))
        effect.addSubview(label)
        try writePNG(of: effect, to: destination)
    }

    private static func writePNG(of view: NSView, to destination: URL) throws {
        view.layoutSubtreeIfNeeded()
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0,
              let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(ceil(bounds.width * scale)),
                pixelsHigh: Int(ceil(bounds.height * scale)),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0)
        else { throw CaptureError.invalidBounds }
        bitmap.size = bounds.size
        view.cacheDisplay(in: bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw CaptureError.encodingFailed
        }
        try data.write(to: destination, options: .atomic)
    }

    private enum CaptureError: Error {
        case missingWindowFrame
        case invalidBounds
        case encodingFailed
    }
}

private final class EphemeralPreferenceStore: PreferenceStore {
    private var storage: [String: Any] = [:]

    func data(forKey defaultName: String) -> Data? { storage[defaultName] as? Data }
    func double(forKey defaultName: String) -> Double { storage[defaultName] as? Double ?? 0 }
    func object(forKey defaultName: String) -> Any? { storage[defaultName] }
    func set(_ value: Any?, forKey defaultName: String) { storage[defaultName] = value }
    func removeObject(forKey defaultName: String) { storage.removeValue(forKey: defaultName) }
}
#endif

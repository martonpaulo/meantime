import AppKit
import MeantimeKit

/// Boundary-aligned update scheduler. Fires exactly when the coarsest visible
/// clock's shown value next changes — never on a fixed interval — so a bar that
/// shows only hours wakes about once an hour. Re-syncs immediately on clock,
/// time-zone, and wake events.
///
/// A single app-lifetime instance: its system observations stay active for as
/// long as the app runs, which is exactly the intent.
@MainActor
final class ClockTicker {
    /// Called on every boundary and system change; refresh the UI here.
    var onTick: (() -> Void)?
    /// Supplies the currently visible clocks so the next boundary can be planned.
    var visibleProvider: (() -> [ClockUpdatePlanner.Visible])?

    private var timer: Timer?

    init() {
        observeSystemChanges()
    }

    /// Refresh now and arm the next boundary. Call whenever visibility changes.
    func refresh() {
        fire()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func fire() {
        onTick?()
        reschedule()
    }

    private func reschedule() {
        timer?.invalidate()
        timer = nil

        guard let visible = visibleProvider?(),
              let next = ClockUpdatePlanner.nextUpdate(after: Date(), visible: visible)
        else { return } // nothing visible shows changing time → no timer at all

        // Scheduled to an absolute date in common modes so it still fires while a
        // menu/panel is tracking, and re-armed each time to avoid drift.
        let timer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.fire() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func observeSystemChanges() {
        let center = NotificationCenter.default
        center.addObserver(forName: .NSSystemClockDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.fire() }
        }
        center.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.fire() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.fire() }
        }
    }
}

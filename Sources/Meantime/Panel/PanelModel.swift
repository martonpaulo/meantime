import Foundation
import Observation

/// Transient panel state. The time-travel offset is deliberately not persisted —
/// it is a "peek" that resets every time the panel opens.
@MainActor
@Observable
final class PanelModel {
    /// Hours added to "now" across every clock. Range is owned by the view.
    var travelHours: Double = 0

    var isTraveling: Bool { abs(travelHours) >= 0.25 }

    func reset() {
        travelHours = 0
    }

    /// The instant the panel is previewing, given the real current time.
    func previewDate(from now: Date) -> Date {
        now.addingTimeInterval(travelHours * 3600)
    }
}

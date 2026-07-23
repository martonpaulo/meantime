import Foundation
import Observation

/// The observable "now". The ticker advances it exactly on each boundary so both
/// the AppKit status items and the SwiftUI panel re-read the same instant. Never
/// a private counter that could drift: it is always the real system clock.
@MainActor
@Observable
final class TimeSource {
    private(set) var now: Date

    init(now: Date = Date()) {
        self.now = now
    }

    func advance() {
        now = Date()
    }
}

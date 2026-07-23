import Foundation

/// A Save-gated clock edit. New clocks do not enter preferences until commit;
/// repeated commits are harmless.
public struct ClockEditDraft: Equatable, Sendable {
    public let original: WorldClock?
    public var clock: WorldClock
    public private(set) var isCommitted = false

    public init(existing clock: WorldClock) {
        original = clock
        self.clock = clock
    }

    public init(newTimeZoneID: String) {
        original = nil
        clock = WorldClock(timeZoneID: newTimeZoneID)
    }

    public var isNew: Bool { original == nil }
    public var hasChanges: Bool { original.map { $0 != clock } ?? true }
    public var validationIssues: [ClockValidationIssue] {
        ClockValidation.issues(for: clock)
    }
    public var canCommit: Bool { hasChanges && validationIssues.isEmpty && !isCommitted }

    @MainActor
    @discardableResult
    public mutating func commit(to preferences: Preferences) -> Bool {
        guard canCommit else { return false }
        if original == nil {
            preferences.addClock(clock)
        } else {
            preferences.update(clock)
        }
        isCommitted = true
        return true
    }
}


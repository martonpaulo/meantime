import Foundation
import MeantimeKit
import Observation

/// A transient overlay for settings that must preview in the real menu bar but
/// persist only after Save. `Preferences` remains the only durable source of
/// truth; clearing this object always reveals the last saved values.
@MainActor
@Observable
final class SettingsPreview {
    struct AppearanceDraft: Equatable {
        var formatPreset: TimeFormatPreset
        var customPattern: String
        var menuBarLayout: MenuBarLayout
        var combinedSeparator: String
        var textSize: Double
        var elementSpacing: Double

        @MainActor init(preferences: Preferences) {
            formatPreset = TimeFormatPreset.matching(preferences.timeFormat)
            customPattern = preferences.timeFormat.customPattern ?? "HH:mm"
            menuBarLayout = preferences.menuBarLayout
            combinedSeparator = preferences.combinedSeparator
            textSize = preferences.textSize
            elementSpacing = preferences.elementSpacing
        }

        var timeFormat: TimeFormat {
            formatPreset.format ?? .custom(customPattern)
        }

        var isValid: Bool {
            UserInputPolicy.isValidSeparator(combinedSeparator)
                && (formatPreset != .custom
                    || (TimeFormatPattern.isValid(customPattern)
                        && UserInputPolicy.isWithinPatternLimit(customPattern)))
        }

        var appearance: MenuBarAppearance {
            MenuBarAppearance(
                timeFormat: timeFormat,
                layout: menuBarLayout,
                combinedSeparator: combinedSeparator,
                textSize: textSize,
                elementSpacing: elementSpacing)
        }
    }

    @ObservationIgnored private let preferences: Preferences

    var appearanceDraft: AppearanceDraft?
    var clockDraft: WorldClock?

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    var clocks: [WorldClock] {
        guard let clockDraft else { return preferences.clocks }
        guard preferences.clocks.contains(where: { $0.id == clockDraft.id }) else {
            return preferences.clocks + [clockDraft]
        }
        return preferences.clocks.map { $0.id == clockDraft.id ? clockDraft : $0 }
    }

    var timeFormat: TimeFormat { appearanceDraft?.timeFormat ?? preferences.timeFormat }
    var menuBarLayout: MenuBarLayout { appearanceDraft?.menuBarLayout ?? preferences.menuBarLayout }
    var combinedSeparator: String { appearanceDraft?.combinedSeparator ?? preferences.combinedSeparator }
    var textSize: Double { appearanceDraft?.textSize ?? preferences.textSize }
    var elementSpacing: Double { appearanceDraft?.elementSpacing ?? preferences.elementSpacing }

    var hasAppearanceChanges: Bool {
        guard let appearanceDraft else { return false }
        return appearanceDraft != AppearanceDraft(preferences: preferences)
    }

    var canSaveAppearance: Bool { appearanceDraft?.isValid == true }

    func beginAppearanceEditing() {
        if appearanceDraft == nil {
            appearanceDraft = AppearanceDraft(preferences: preferences)
        }
    }

    func saveAppearance() {
        guard let draft = appearanceDraft, draft.isValid else { return }
        preferences.applyAppearance(draft.appearance)
        appearanceDraft = nil
    }

    func discardAppearance() {
        appearanceDraft = nil
    }

    func preview(clock: WorldClock) {
        clockDraft = clock
    }

    func discardClock() {
        clockDraft = nil
    }
}

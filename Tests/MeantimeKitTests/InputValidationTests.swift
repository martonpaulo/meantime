import Foundation
import Testing
@testable import MeantimeKit

@Suite struct UserInputPolicyTests {
    @Test func emojiRequiresExactlyOneExtendedGraphemeCluster() {
        #expect(UserInputPolicy.isValidEmoji("🌍"))
        #expect(UserInputPolicy.isValidEmoji("👨‍👩‍👧‍👦"))
        #expect(UserInputPolicy.isValidEmoji("🇧🇷"))
        #expect(!UserInputPolicy.isValidEmoji(nil))
        #expect(!UserInputPolicy.isValidEmoji(""))
        #expect(!UserInputPolicy.isValidEmoji("🌍🌎"))
        #expect(!UserInputPolicy.isValidEmoji("NY"))
    }

    @Test func textFieldsRespectGraphemeLimits() {
        #expect(UserInputPolicy.isValidLabel(String(repeating: "a", count: 40)))
        #expect(!UserInputPolicy.isValidLabel(String(repeating: "a", count: 41)))
        #expect(UserInputPolicy.isValidLeadingText("New York"))
        #expect(!UserInputPolicy.isValidLeadingText("New York!"))
        #expect(UserInputPolicy.isValidSeparator(""))
        #expect(UserInputPolicy.isValidSeparator(" · "))
        #expect(!UserInputPolicy.isValidSeparator(" / / "))
        #expect(UserInputPolicy.isValidLeadingText("القاهرة"))
        #expect(UserInputPolicy.isValidLabel(String(repeating: "e\u{301}", count: 40)))
        #expect(!UserInputPolicy.isValidLabel(String(repeating: "e\u{301}", count: 41)))
    }

    @Test func clockValidationReportsTheRelevantField() {
        var clock = WorldClock(timeZoneID: "UTC", customEmoji: "🌍🌎",
                               adornmentStyle: .emoji)
        #expect(ClockValidation.issues(for: clock) == [.emojiMustBeSingleCharacter])

        clock.adornmentStyle = .text
        clock.customText = ""
        #expect(ClockValidation.issues(for: clock) == [.leadingTextRequired])
    }

    @Test func customPatternHasAGenerousSafetyLimitWithoutRestrictingVocabulary() {
        #expect(TimeFormatPattern.isValid("GGGGG yyyy-MM-dd 'at' HH:mm:ss.SSS XXX VV"))
        #expect(TimeFormatPattern.isValid(String(repeating: "x", count: 256)))
        #expect(!TimeFormatPattern.isValid(String(repeating: "x", count: 257)))
    }
}

@Suite @MainActor struct ClockEditDraftTests {
    @Test func newDraftDoesNotPersistUntilCommitAndCommitIsIdempotent() {
        let prefs = Preferences(store: TestPreferenceStore())
        let initial = prefs.clocks
        var draft = ClockEditDraft(newTimeZoneID: "UTC")
        draft.clock.customLabel = "Coordinated"

        #expect(prefs.clocks == initial)
        let firstCommit = draft.commit(to: prefs)
        #expect(firstCommit)
        #expect(prefs.clocks.count == initial.count + 1)
        #expect(prefs.clocks.last?.displayLabel == "Coordinated")
        let secondCommit = draft.commit(to: prefs)
        #expect(!secondCommit)
        #expect(prefs.clocks.count == initial.count + 1)
    }

    @Test func existingDraftUpdatesOnlyItsClock() {
        let prefs = Preferences(store: TestPreferenceStore())
        let original = WorldClock(timeZoneID: "Europe/Paris")
        prefs.clocks = [original]
        var draft = ClockEditDraft(existing: original)
        draft.clock.customLabel = "Team"

        let committed = draft.commit(to: prefs)
        #expect(committed)
        #expect(prefs.clocks == [draft.clock])
    }
}

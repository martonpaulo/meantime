import Foundation
import Testing
@testable import MeantimeKit

private func utc(_ year: Int, _ month: Int, _ day: Int,
                 _ hour: Int, _ minute: Int, _ second: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
}

@Suite struct RegionFlagTests {
    @Test func mapsKnownZonesToFlags() {
        #expect(RegionFlag.emoji(for: "America/Los_Angeles") == "🇺🇸")
        #expect(RegionFlag.emoji(for: "Asia/Bangkok") == "🇹🇭")
        #expect(RegionFlag.emoji(for: "Europe/Oslo") == "🇳🇴")
    }

    @Test func unknownZoneFallsBackToGlobe() {
        #expect(RegionFlag.emoji(for: "Not/AZone") == RegionFlag.fallback)
        #expect(RegionFlag.emoji(for: "UTC") == RegionFlag.fallback)
    }

    @Test func regionCodeMustBeTwoLetters() {
        #expect(RegionFlag.emoji(regionCode: "US") == "🇺🇸")
        #expect(RegionFlag.emoji(regionCode: "USA") == nil)
        #expect(RegionFlag.emoji(regionCode: "1") == nil)
    }
}

@Suite struct CityLabelTests {
    @Test func humanizesLastComponent() {
        #expect(CityLabel.name(for: "America/Sao_Paulo") == "Sao Paulo")
        #expect(CityLabel.name(for: "America/Argentina/Buenos_Aires") == "Buenos Aires")
        #expect(CityLabel.name(for: "Europe/Oslo") == "Oslo")
    }
}

@Suite struct ClockFormatterTests {
    let formatter = ClockFormatter()
    let posix = Locale(identifier: "en_US_POSIX")
    // 2026-07-23 09:47:30 UTC; Los Angeles is PDT (UTC-7) that date.
    let moment = utc(2026, 7, 23, 9, 47, 30)

    @Test func customPatternHonoredVerbatimInZone() {
        let la = TimeZone(identifier: "America/Los_Angeles")!
        #expect(formatter.string(for: moment, timeZone: la, format: .custom("HH:mm"), locale: posix) == "02:47")
        #expect(formatter.string(for: moment, timeZone: la, format: .custom("h:mm a"), locale: posix) == "2:47 AM")
    }

    @Test func explicitHourFieldsResistSystemTwelveHourOverride() {
        // A locale carrying a 12-hour override (what the macOS "24-Hour Time"
        // toggle injects) must not rewrite an explicit H/HH pattern into "h a".
        var components = Locale.Components(identifier: "en_US")
        components.hourCycle = .oneToTwelve
        let twelveHourLocale = Locale(components: components)
        let la = TimeZone(identifier: "America/Los_Angeles")! // 02:47 at `moment`
        #expect(formatter.string(for: moment, timeZone: la, format: .custom("HH:mm"),
                                 locale: twelveHourLocale) == "02:47")
        // And the reverse: an explicit 12-hour pattern survives a 24-hour locale.
        var reverse = Locale.Components(identifier: "en_US")
        reverse.hourCycle = .zeroToTwentyThree
        #expect(formatter.string(for: moment, timeZone: la, format: .custom("h:mm a"),
                                 locale: Locale(components: reverse)) == "2:47 AM")
    }

    @Test func reusesFormatterInstanceForSameKey() {
        let utcZone = TimeZone(identifier: "UTC")!
        _ = formatter.string(for: moment, timeZone: utcZone, format: .custom("HH:mm"), locale: posix)
        // Second call for the same key must produce the same result (cache hit).
        #expect(formatter.string(for: moment, timeZone: utcZone, format: .custom("HH:mm"), locale: posix) == "09:47")
    }

    @Test func requestedUTS35FieldsAndLiteralTextAreAccepted() {
        let patterns = [
            "yy", "yyyy", "M", "MM", "MMM", "MMMM", "d", "dd", "EEE", "EEEE",
            "a", "h", "hh", "H", "HH", "m", "mm", "s", "ss", "z", "zzzz", "XXX", "VV",
            "yyyy/MM/dd", "dd-MM-yy", "EEE, d MMM · HH:mm:ss z",
            "'Meeting at' h:mm a", "'Sam''s time:' HH:mm",
        ]
        let utcZone = TimeZone(identifier: "UTC")!

        for pattern in patterns {
            #expect(TimeFormatPattern.isValid(pattern), "Expected valid pattern: \(pattern)")
            #expect(!formatter.string(for: moment, timeZone: utcZone,
                                      format: .custom(pattern), locale: posix).isEmpty)
        }
    }

    @Test func patternValidationRejectsEmptyAndUnbalancedLiterals() {
        #expect(!TimeFormatPattern.isValid(""))
        #expect(!TimeFormatPattern.isValid("   "))
        #expect(!TimeFormatPattern.isValid("HH 'unfinished"))
        #expect(TimeFormatPattern.isValid("HH 'o''clock'"))
    }
}

@Suite struct TimeFormatPresetTests {
    @Test func commonFormatsMapToStablePresets() {
        #expect(TimeFormatPreset.matching(.system) == .systemDefault)
        #expect(TimeFormatPreset.matching(.custom("HH:mm")) == .twentyFourHour)
        #expect(TimeFormatPreset.matching(.custom("h:mm a")) == .twelveHour)
        #expect(TimeFormatPreset.matching(.custom("EEE d MMM · HH:mm")) == .dateAndTime)
        #expect(TimeFormatPreset.matching(.custom("VV")) == .custom)
    }

    @Test func everyNonCustomPresetHasAValidFormat() {
        for preset in TimeFormatPreset.allCases where preset != .custom {
            #expect(preset.format != nil)
            if let pattern = preset.format?.customPattern {
                #expect(TimeFormatPattern.isValid(pattern))
            }
        }
    }
}

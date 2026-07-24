import Foundation
import Testing
@testable import MeantimeKit

/// Locales are pinned so tests never depend on the machine's 12/24-hour setting.
private let h12 = Locale(identifier: "en_US")   // 12-hour clock
private let h24 = Locale(identifier: "en_GB")   // 24-hour clock

@Suite struct TimeOfDayInputTests {
    typealias Time = TimeOfDayInput.Time

    @Test func detectsHourCycleFromLocale() {
        #expect(TimeOfDayInput.uses12Hour(locale: h12))
        #expect(!TimeOfDayInput.uses12Hour(locale: h24))
    }

    // MARK: Two-digit segment cap

    @Test func segmentKeepsAtMostTwoDigits() {
        #expect(TimeOfDayInput.sanitizedDigits("1") == "1")
        #expect(TimeOfDayInput.sanitizedDigits("12") == "12")
        #expect(TimeOfDayInput.sanitizedDigits("123") == "23")   // keeps the last two typed
        #expect(TimeOfDayInput.sanitizedDigits("1a2b") == "12")  // non-digits dropped
        #expect(TimeOfDayInput.sanitizedDigits("") == "")
        #expect(TimeOfDayInput.sanitizedDigits("abc") == "")
    }

    // MARK: Rejection of incomplete/invalid input

    @Test func rejectsEmptyOrNonNumericSegments() {
        #expect(TimeOfDayInput.parse(hour: "", minute: "30", meridiem: .am, locale: h12) == nil)
        #expect(TimeOfDayInput.parse(hour: "5", minute: "", meridiem: .am, locale: h12) == nil)
        #expect(TimeOfDayInput.parse(hour: "-", minute: "aa", meridiem: nil, locale: h24) == nil)
    }

    // MARK: Minute normalization

    @Test func minutesResolveIntoTheValidRange() {
        #expect(TimeOfDayInput.parse(hour: "9", minute: "05", meridiem: .am, locale: h12)
                == Time(hour: 9, minute: 5))
        #expect(TimeOfDayInput.parse(hour: "9", minute: "75", meridiem: .am, locale: h12)
                == Time(hour: 9, minute: 59))   // overflow clamps to 59
    }

    // MARK: 12-hour normalization

    @Test func twelveHourPairsHourWithMeridiem() {
        #expect(TimeOfDayInput.parse(hour: "3", minute: "00", meridiem: .pm, locale: h12)
                == Time(hour: 15, minute: 0))
        #expect(TimeOfDayInput.parse(hour: "12", minute: "00", meridiem: .am, locale: h12)
                == Time(hour: 0, minute: 0))    // 12 AM = midnight
        #expect(TimeOfDayInput.parse(hour: "12", minute: "00", meridiem: .pm, locale: h12)
                == Time(hour: 12, minute: 0))   // 12 PM = noon
    }

    @Test func twelveHourReadsOverflowHoursAsTwentyFourHour() {
        // The documented example: typing 15 on a 12-hour clock resolves to 3 PM.
        #expect(TimeOfDayInput.parse(hour: "15", minute: "00", meridiem: .am, locale: h12)
                == Time(hour: 15, minute: 0))
        #expect(TimeOfDayInput.segments(for: Time(hour: 15, minute: 0), locale: h12).hour == "3")
        #expect(TimeOfDayInput.segments(for: Time(hour: 15, minute: 0), locale: h12).meridiem == .pm)
        // 0 and 24 both read as midnight.
        #expect(TimeOfDayInput.parse(hour: "0", minute: "00", meridiem: .pm, locale: h12)
                == Time(hour: 0, minute: 0))
        #expect(TimeOfDayInput.parse(hour: "24", minute: "00", meridiem: .am, locale: h12)
                == Time(hour: 0, minute: 0))
    }

    // MARK: 24-hour normalization

    @Test func twentyFourHourClampsHoursIntoRange() {
        #expect(TimeOfDayInput.parse(hour: "0", minute: "00", meridiem: nil, locale: h24)
                == Time(hour: 0, minute: 0))
        #expect(TimeOfDayInput.parse(hour: "23", minute: "59", meridiem: nil, locale: h24)
                == Time(hour: 23, minute: 59))
        #expect(TimeOfDayInput.parse(hour: "99", minute: "00", meridiem: nil, locale: h24)
                == Time(hour: 23, minute: 0))
    }

    // MARK: Formatting round-trip

    @Test func segmentsFormatPerLocale() {
        let afternoon = Time(hour: 15, minute: 5)
        let twelve = TimeOfDayInput.segments(for: afternoon, locale: h12)
        #expect(twelve.hour == "3")
        #expect(twelve.minute == "05")     // minutes always two digits
        #expect(twelve.meridiem == .pm)

        let twentyFour = TimeOfDayInput.segments(for: afternoon, locale: h24)
        #expect(twentyFour.hour == "15")
        #expect(twentyFour.minute == "05")
        #expect(twentyFour.meridiem == nil)

        // Midnight shows as 12 AM on a 12-hour clock, 0 on a 24-hour one.
        #expect(TimeOfDayInput.segments(for: Time(hour: 0, minute: 0), locale: h12).hour == "12")
        #expect(TimeOfDayInput.segments(for: Time(hour: 0, minute: 0), locale: h12).meridiem == .am)
        #expect(TimeOfDayInput.segments(for: Time(hour: 0, minute: 0), locale: h24).hour == "0")
    }

    @Test func parsingAndFormattingRoundTrips() {
        for hour in 0...23 {
            for minute in [0, 5, 30, 59] {
                let time = Time(hour: hour, minute: minute)
                for locale in [h12, h24] {
                    let segments = TimeOfDayInput.segments(for: time, locale: locale)
                    let reparsed = TimeOfDayInput.parse(
                        hour: segments.hour, minute: segments.minute,
                        meridiem: segments.meridiem, locale: locale)
                    #expect(reparsed == time, "round trip failed for \(time) in \(locale.identifier)")
                }
            }
        }
    }
}

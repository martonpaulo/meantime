import Foundation

/// Locale-aware parsing, normalization, validation, and formatting for the
/// panel's segmented time editor. Pure (Foundation only): the editor view
/// renders segments and commits their raw strings through here, owning no time
/// logic of its own.
///
/// The editor shows `[h]:[mm]` on a 24-hour locale and `[h]:[mm] [AM/PM]` on a
/// 12-hour one. Each numeric segment holds one or two digits.
public enum TimeOfDayInput {
    /// AM/PM half of a 12-hour clock.
    public enum Meridiem: String, Sendable, Equatable, CaseIterable {
        case am
        case pm

        public var toggled: Meridiem { self == .am ? .pm : .am }
    }

    /// A validated wall-clock time of day. `hour` is always 24-hour (0...23);
    /// the 12-hour presentation is derived on demand.
    public struct Time: Equatable, Sendable {
        public var hour: Int
        public var minute: Int

        public init(hour: Int, minute: Int) {
            self.hour = hour
            self.minute = minute
        }
    }

    /// Whether `locale` presents time on a 12-hour clock (AM/PM) rather than
    /// 24-hour. Derived from the locale's own preferred hour template ("j"), the
    /// same signal the system uses, so it tracks the Mac's 12/24-hour setting.
    public static func uses12Hour(locale: Locale = .current) -> Bool {
        let template = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? "h"
        // 12-hour skeletons use h/K (and usually an 'a' period marker); 24-hour
        // ones use H/k. Presence of any 12-hour hour letter is decisive.
        return template.contains("h") || template.contains("K")
    }

    /// Keeps only the leading decimal digits of `raw`, capped at `maxLength`
    /// (two for a time segment). Non-digits and overflow beyond the cap are
    /// dropped, so a numeric segment never holds more than two characters. Extra
    /// digits keep the most recently typed ones, matching native field editing.
    public static func sanitizedDigits(_ raw: String, maxLength: Int = 2) -> String {
        let digits = raw.filter { $0.isDigit }
        return String(digits.suffix(maxLength))
    }

    /// Parses raw segment strings into a normalized `Time`, or `nil` when a
    /// segment is empty or non-numeric; incomplete input is rejected on commit.
    ///
    /// Normalization:
    /// - Minutes clamp into `00...59`.
    /// - 24-hour: hours clamp into `0...23`.
    /// - 12-hour: `1...12` pair with `meridiem`; `0`/`24` read as midnight
    ///   (`12 AM`); `13...23` are read as their 24-hour value, so `15` becomes
    ///   `3 PM`; anything larger clamps to the top of the day.
    public static func parse(hour rawHour: String, minute rawMinute: String,
                             meridiem: Meridiem?, locale: Locale = .current) -> Time? {
        guard let hourValue = digitValue(of: sanitizedDigits(rawHour)),
              let minuteValue = digitValue(of: sanitizedDigits(rawMinute)) else {
            return nil
        }

        let minute = clamp(minuteValue, to: 0...59)
        let hour24: Int
        if uses12Hour(locale: locale) {
            hour24 = normalized12Hour(hourValue, meridiem: meridiem ?? .am)
        } else {
            hour24 = clamp(hourValue, to: 0...23)
        }
        return Time(hour: hour24, minute: minute)
    }

    /// The display strings for `time` in `locale`: an unpadded hour, a
    /// zero-padded minute, and a meridiem on a 12-hour locale (`nil` on a
    /// 24-hour one).
    public static func segments(for time: Time, locale: Locale = .current)
        -> (hour: String, minute: String, meridiem: Meridiem?) {
        let minute = String(format: "%02d", clamp(time.minute, to: 0...59))
        let hour24 = clamp(time.hour, to: 0...23)
        if uses12Hour(locale: locale) {
            let twelve = hour24 % 12
            let displayHour = twelve == 0 ? 12 : twelve
            return ("\(displayHour)", minute, hour24 >= 12 ? .pm : .am)
        }
        return ("\(hour24)", minute, nil)
    }

    // MARK: - Internals

    /// Maps a typed hour and AM/PM selection to a 24-hour hour.
    private static func normalized12Hour(_ typed: Int, meridiem: Meridiem) -> Int {
        // Values that only make sense as 24-hour input (0 and 13...) are read as
        // such, so "15" resolves to 3 PM regardless of the AM/PM selection.
        let capped = min(typed, 24)
        switch capped {
        case 1...12:
            let base = capped % 12               // 12 -> 0, so 12 AM = 0, 12 PM = 12
            return meridiem == .pm ? base + 12 : base
        case 0, 24:
            return 0                             // midnight
        default:
            return capped                        // 13...23 already 24-hour
        }
    }

    private static func digitValue(of digits: String) -> Int? {
        guard !digits.isEmpty else { return nil }
        var value = 0
        for character in digits {
            guard let digit = character.wholeNumberValue, (0...9).contains(digit) else {
                return nil
            }
            value = value * 10 + digit
        }
        return value
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

private extension Character {
    /// A single 0–9 decimal digit, in any script the locale might present.
    var isDigit: Bool {
        guard let value = wholeNumberValue else { return false }
        return isNumber && (0...9).contains(value) && unicodeScalars.count == 1
    }
}

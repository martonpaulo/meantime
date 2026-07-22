import Foundation

/// Derives a flag emoji for a time zone from its ISO 3166-1 region. When the
/// region is unknown the globe is used; a clock's emoji is always overridable,
/// so this only needs to be a good default.
public enum RegionFlag {
    /// Shown when a zone has no known region (or an odd identifier).
    public static let fallback = "🌐"

    /// The flag emoji for a time-zone identifier, or the globe fallback.
    public static func emoji(for timeZoneID: String) -> String {
        guard let region = TimeZoneRegions.byIdentifier[timeZoneID] else { return fallback }
        return emoji(regionCode: region) ?? fallback
    }

    /// Converts an ISO 3166-1 alpha-2 code (e.g. `US`) to its flag emoji by
    /// pairing each letter's Regional Indicator Symbol. Returns nil for input
    /// that is not two ASCII letters.
    public static func emoji(regionCode: String) -> String? {
        let letters = Array(regionCode.uppercased().unicodeScalars)
        guard letters.count == 2 else { return nil }
        var view = String.UnicodeScalarView()
        for letter in letters {
            guard (65...90).contains(letter.value),
                  let indicator = Unicode.Scalar(0x1F1E6 + (letter.value - 65))
            else { return nil }
            view.append(indicator)
        }
        return String(view)
    }
}

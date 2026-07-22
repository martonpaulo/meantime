import Foundation

/// Produces a readable default label from an IANA identifier by taking the last
/// path component and unslugging it, e.g.
/// `America/Argentina/Buenos_Aires` -> `Buenos Aires`.
public enum CityLabel {
    public static func name(for timeZoneID: String) -> String {
        let last = timeZoneID.split(separator: "/").last.map(String.init) ?? timeZoneID
        return last.replacingOccurrences(of: "_", with: " ")
    }
}

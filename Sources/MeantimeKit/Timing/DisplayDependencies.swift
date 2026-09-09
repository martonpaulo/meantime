import Foundation

/// What a rendered clock's output depends on, beyond the one field boundary the
/// cadence describes.
///
/// The accepted UTS-35 vocabulary is wider than the cadence classifier: `a`,
/// `b`, `B` and the zone families all change within a day while containing no
/// hour, minute or second field, so a pattern built from them alone used to sit
/// stale until midnight.
public struct DisplayDependencies: Sendable, Equatable {
    /// The finest fixed field the output shows, which sets the ordinary cadence.
    public let granularity: TimeGranularity
    /// The output names a localized day period (`a`, `b`, `B`), which changes at
    /// noon, midnight, or a locale's own flexible period boundaries.
    public let showsDayPeriod: Bool
    /// The output names the zone (`z Z O v V X x`), which changes when the zone's
    /// offset does, if it changes at all.
    public let showsZoneDisplay: Bool

    /// Whether the exact change instants have to be found by comparing rendered
    /// output. They do not when a minute or hour field is present: those
    /// boundaries already fire at least as often as a day period or an offset
    /// transition can move.
    public var needsRenderedComparison: Bool {
        granularity == .day && (showsDayPeriod || showsZoneDisplay)
    }

    public static func of(renderMode: ClockRenderMode, format: TimeFormat) -> DisplayDependencies {
        guard renderMode != .analogClock, case let .custom(pattern) = format else {
            // An analog face and the system short time both move every minute.
            return DisplayDependencies(granularity: .minute,
                                       showsDayPeriod: false, showsZoneDisplay: false)
        }
        let fields = TimeFormatPattern.fields(in: pattern)
        return DisplayDependencies(
            granularity: TimeGranularity.from(pattern: pattern),
            showsDayPeriod: fields.contains { "abB".contains($0) },
            showsZoneDisplay: fields.contains { "zZOvVXx".contains($0) })
    }
}

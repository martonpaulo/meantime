import Foundation

/// Compact GMT-offset captions ("GMT−3", "GMT+5:30") for panel rows, so a
/// glance tells how far away a clock is. DST-aware: computed at the given
/// instant, not from the zone's base offset.
public enum ZoneOffset {
    public static func caption(for timeZone: TimeZone, at date: Date) -> String {
        caption(offsetSeconds: timeZone.secondsFromGMT(for: date))
    }

    public static func caption(offsetSeconds seconds: Int) -> String {
        if seconds == 0 { return "GMT" }
        let sign = seconds > 0 ? "+" : "−"
        let magnitude = abs(seconds)
        let hours = magnitude / 3600
        let minutes = (magnitude % 3600) / 60
        return minutes == 0 ? "GMT\(sign)\(hours)" : "GMT\(sign)\(hours):\(String(format: "%02d", minutes))"
    }
}

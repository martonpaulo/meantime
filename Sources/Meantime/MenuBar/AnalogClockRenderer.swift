import AppKit
import Foundation

/// Draws a tiny analog clock face for the "clock only" menu-bar mode. Returned as
/// a template image so the menu bar tints it for light/dark automatically.
enum AnalogClockRenderer {
    static func image(for date: Date, timeZone: TimeZone, pointSize: CGFloat) -> NSImage {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(parts.hour ?? 0)
        let minute = Double(parts.minute ?? 0)

        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2 - 1
            NSColor.black.setStroke() // template image: the system re-tints this

            let face = NSBezierPath(ovalIn: NSRect(
                x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            face.lineWidth = max(1, pointSize * 0.08)
            face.stroke()

            // 12 o'clock points up; time advances clockwise (decreasing angle).
            let minuteAngle = CGFloat.pi / 2 - CGFloat(minute / 60) * 2 * .pi
            let hourFraction = (hour.truncatingRemainder(dividingBy: 12) + minute / 60) / 12
            let hourAngle = CGFloat.pi / 2 - CGFloat(hourFraction) * 2 * .pi

            drawHand(from: center, angle: hourAngle, length: radius * 0.5, width: max(1, pointSize * 0.10))
            drawHand(from: center, angle: minuteAngle, length: radius * 0.82, width: max(1, pointSize * 0.07))
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawHand(from center: CGPoint, angle: CGFloat, length: CGFloat, width: CGFloat) {
        let end = CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length)
        let hand = NSBezierPath()
        hand.move(to: center)
        hand.line(to: end)
        hand.lineWidth = width
        hand.lineCapStyle = .round
        hand.stroke()
    }
}

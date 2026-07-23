#!/usr/bin/env swift
// Renders the Meantime app icon: a premium "world time" identity — a deep-space
// blue plate holding a glassy globe dial (meridians as the clock face), lit with
// a specular top-left highlight, white hands and an orange second hand.
// Usage: swift scripts/make-icon.swift
import AppKit

let iconsetPath = "artifacts/AppIcon.iconset"
let outputPath = "Support/AppIcon.icns"
let fileManager = FileManager.default
try? fileManager.removeItem(atPath: iconsetPath)
try fileManager.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

func drawIcon() -> NSImage {
    let canvas: CGFloat = 1024
    let image = NSImage(size: NSSize(width: canvas, height: canvas))
    image.lockFocus()
    defer { image.unlockFocus() }

    let center = NSPoint(x: 512, y: 512)

    // ── Plate: luminous azure-to-indigo gradient, gently glowing top-center —
    //    the vibrant-gradient-plus-white-glyph language of first-party icons.
    let plateRect = NSRect(x: 100, y: 100, width: 824, height: 824)
    let plate = NSBezierPath(roundedRect: plateRect, xRadius: 185, yRadius: 185)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.28, green: 0.55, blue: 0.98, alpha: 1),
        NSColor(calibratedRed: 0.12, green: 0.20, blue: 0.60, alpha: 1),
    ])!.draw(in: plate, angle: -90)

    NSGraphicsContext.current?.saveGraphicsState()
    plate.addClip()
    // Soft light bloom behind the dial.
    NSGradient(colors: [
        NSColor(calibratedWhite: 1, alpha: 0.22),
        NSColor(calibratedWhite: 1, alpha: 0.0),
    ])!.draw(in: NSBezierPath(rect: plateRect), relativeCenterPosition: NSPoint(x: 0, y: 0.45))
    // Rim light on the plate's top edge.
    let rim = NSBezierPath(roundedRect: plateRect.insetBy(dx: 2, dy: 2), xRadius: 183, yRadius: 183)
    rim.lineWidth = 4
    NSColor(calibratedWhite: 1, alpha: 0.22).setStroke()
    rim.stroke()
    NSGraphicsContext.current?.restoreGraphicsState()

    // ── Dial: a thin glass ring — nothing else. The plate is the face.
    let dialRadius: CGFloat = 318
    let dialRect = NSRect(x: center.x - dialRadius, y: center.y - dialRadius,
                          width: dialRadius * 2, height: dialRadius * 2)

    NSGraphicsContext.current?.saveGraphicsState()
    let ringShadow = NSShadow()
    ringShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    ringShadow.shadowBlurRadius = 30
    ringShadow.shadowOffset = NSSize(width: 0, height: -12)
    ringShadow.set()
    let ring = NSBezierPath(ovalIn: dialRect)
    ring.lineWidth = 22
    NSColor(calibratedWhite: 1, alpha: 0.95).setStroke()
    ring.stroke()
    NSGraphicsContext.current?.restoreGraphicsState()

    // ── Minimal markers: four quarter dots inside the ring.
    for mark in stride(from: 0, to: 12, by: 3) {
        let angle = CGFloat(mark) / 12 * 2 * .pi
        let radius = dialRadius - 58
        let dot: CGFloat = 24
        NSColor(calibratedWhite: 1, alpha: 0.9).setFill()
        NSBezierPath(ovalIn: NSRect(
            x: center.x + cos(angle) * radius - dot / 2,
            y: center.y + sin(angle) * radius - dot / 2,
            width: dot, height: dot)).fill()
    }

    // ── Hands at 10:09:30 — white with depth shadows; orange second hand.
    func hand(angle: CGFloat, length: CGFloat, tail: CGFloat, width: CGFloat,
              color: NSColor, shadowBlur: CGFloat) {
        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadow.shadowBlurRadius = shadowBlur
        shadow.shadowOffset = NSSize(width: 0, height: -9)
        shadow.set()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: center.x - cos(angle) * tail, y: center.y - sin(angle) * tail))
        path.line(to: NSPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length))
        path.lineWidth = width
        path.lineCapStyle = .round
        color.setStroke()
        path.stroke()
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    let seconds = 30.0
    let minutes = 9.0 + seconds / 60
    let hours = 10.0 + minutes / 60
    let hourAngle = CGFloat.pi / 2 - CGFloat(hours.truncatingRemainder(dividingBy: 12) / 12) * 2 * .pi
    let minuteAngle = CGFloat.pi / 2 - CGFloat(minutes / 60) * 2 * .pi
    let secondAngle = CGFloat.pi / 2 - CGFloat(seconds / 60) * 2 * .pi

    let handColor = NSColor(calibratedWhite: 1, alpha: 1)
    hand(angle: hourAngle, length: 158, tail: 0, width: 40, color: handColor, shadowBlur: 14)
    hand(angle: minuteAngle, length: 238, tail: 0, width: 30, color: handColor, shadowBlur: 18)
    let orange = NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.04, alpha: 1) // Apple orange
    hand(angle: secondAngle, length: 258, tail: 64, width: 10, color: orange, shadowBlur: 18)

    // ── Hub: white base, orange pin.
    handColor.setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - 28, y: center.y - 28, width: 56, height: 56)).fill()
    orange.setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - 13, y: center.y - 13, width: 26, height: 26)).fill()

    return image
}

func writePNG(_ image: NSImage, pixels: Int, to url: URL) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let master = drawIcon()
for size in [16, 32, 128, 256, 512] {
    let base = URL(fileURLWithPath: iconsetPath)
    try writePNG(master, pixels: size, to: base.appendingPathComponent("icon_\(size)x\(size).png"))
    try writePNG(master, pixels: size * 2, to: base.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetPath, "-o", outputPath]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("wrote \(outputPath)")

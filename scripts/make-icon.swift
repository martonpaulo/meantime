#!/usr/bin/env swift
// Renders the Meantime app icon (a clean clock on an indigo-to-blue plate) at
// every required macOS resolution and writes Support/AppIcon.icns.
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

    // Rounded-square plate with a vertical indigo → blue gradient.
    let plate = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824),
                             xRadius: 185, yRadius: 185)
    NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.48, alpha: 1),
               ending: NSColor(calibratedRed: 0.30, green: 0.48, blue: 0.94, alpha: 1))!
        .draw(in: plate, angle: -90)

    let center = NSPoint(x: 512, y: 512)
    let faceRadius: CGFloat = 300

    // Clock face.
    let faceRect = NSRect(x: center.x - faceRadius, y: center.y - faceRadius,
                          width: faceRadius * 2, height: faceRadius * 2)
    NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
    NSBezierPath(ovalIn: faceRect).fill()

    let ink = NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.48, alpha: 1)

    // Hour ticks.
    ink.withAlphaComponent(0.85).setStroke()
    for hour in 0..<12 {
        let angle = CGFloat(hour) / 12 * 2 * .pi
        let isMajor = hour % 3 == 0
        let inner = faceRadius - (isMajor ? 46 : 28)
        let tick = NSBezierPath()
        tick.move(to: NSPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
        tick.line(to: NSPoint(x: center.x + cos(angle) * (faceRadius - 14),
                              y: center.y + sin(angle) * (faceRadius - 14)))
        tick.lineWidth = isMajor ? 20 : 10
        tick.lineCapStyle = .round
        tick.stroke()
    }

    // Hands at a classic 10:10.
    func hand(angle: CGFloat, length: CGFloat, width: CGFloat) {
        let path = NSBezierPath()
        path.move(to: center)
        path.line(to: NSPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length))
        path.lineWidth = width
        path.lineCapStyle = .round
        ink.setStroke()
        path.stroke()
    }
    let minuteAngle = CGFloat.pi / 2 - (10.0 / 60) * 2 * .pi
    let hourAngle = CGFloat.pi / 2 - ((10.0 + 10.0 / 60) / 12) * 2 * .pi
    hand(angle: hourAngle, length: 150, width: 30)
    hand(angle: minuteAngle, length: 226, width: 22)

    // Center hub.
    ink.setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - 22, y: center.y - 22, width: 44, height: 44)).fill()

    image.unlockFocus()
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

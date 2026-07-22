#!/usr/bin/env swift
// Renders the installer DMG background at 1x and 2x. Icon centers must match the
// window/contents layout in scripts/make-dmg.sh: window 660x420, icons at y 250
// (from the top), app at x 185, Applications at x 475.
// Usage: swift scripts/render-dmg-background.swift
import AppKit

let outputPath = "Support/MeantimeInstallerBackground.tiff"
let width: CGFloat = 660
let height: CGFloat = 420
// Icon centers converted from make-dmg's top-left origin to Cocoa's bottom-left.
let iconY: CGFloat = height - 250
let appX: CGFloat = 185
let appsX: CGFloat = 475

func draw() {
    NSGradient(colors: [NSColor(calibratedRed: 0.96, green: 0.97, blue: 1.0, alpha: 1),
                        NSColor(calibratedRed: 0.90, green: 0.93, blue: 0.99, alpha: 1)])!
        .draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)

    let ink = NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.48, alpha: 1)

    func centeredText(_ string: String, font: NSFont, color: NSColor, y: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let text = NSAttributedString(string: string, attributes: attributes)
        let size = text.size()
        text.draw(at: NSPoint(x: (width - size.width) / 2, y: y))
    }

    centeredText("Meantime", font: .systemFont(ofSize: 40, weight: .bold), color: ink, y: height - 96)
    centeredText("Drag Meantime onto Applications to install",
                 font: .systemFont(ofSize: 15, weight: .regular),
                 color: ink.withAlphaComponent(0.65), y: height - 132)

    // Arrow between the two icon slots.
    let arrow = NSBezierPath()
    let startX = appX + 92
    let endX = appsX - 92
    arrow.move(to: NSPoint(x: startX, y: iconY))
    arrow.line(to: NSPoint(x: endX, y: iconY))
    arrow.lineWidth = 6
    arrow.lineCapStyle = .round
    ink.withAlphaComponent(0.45).setStroke()
    arrow.stroke()

    let head = NSBezierPath()
    head.move(to: NSPoint(x: endX, y: iconY))
    head.line(to: NSPoint(x: endX - 22, y: iconY + 14))
    head.move(to: NSPoint(x: endX, y: iconY))
    head.line(to: NSPoint(x: endX - 22, y: iconY - 14))
    head.lineWidth = 6
    head.lineCapStyle = .round
    head.stroke()
}

func rep(scale: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                              pixelsWide: Int(width) * scale, pixelsHigh: Int(height) * scale,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let image = NSImage(size: NSSize(width: width, height: height))
image.addRepresentation(rep(scale: 1))
image.addRepresentation(rep(scale: 2))
try image.tiffRepresentation!.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath)")

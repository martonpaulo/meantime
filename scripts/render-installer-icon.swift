#!/usr/bin/env swift
// Generates Meantime's disk-image/volume icon: the app icon set into a subtle
// drive body so it reads as "the installer", not a second app icon.
// Usage: swift scripts/render-installer-icon.swift
import AppKit

let sourcePath = "Support/AppIcon.icns"
let iconsetPath = "artifacts/AppInstallerIcon.iconset"
let outputPath = "Support/AppInstallerIcon.icns"
let fileManager = FileManager.default
guard let appIcon = NSImage(contentsOfFile: sourcePath) else { fatalError("Missing \(sourcePath)") }
try? fileManager.removeItem(atPath: iconsetPath)
try fileManager.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

func render(pixels: Int) throws -> Data {
    let logicalSize = NSSize(width: 1024, height: 1024)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = logicalSize
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: logicalSize).fill()

    let bodyRect = NSRect(x: 122, y: 82, width: 780, height: 860)
    let body = NSBezierPath(roundedRect: bodyRect, xRadius: 142, yRadius: 142)
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 34
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.set()
    NSColor(calibratedWhite: 0.88, alpha: 1).setFill()
    body.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGradient(colors: [NSColor(calibratedWhite: 0.99, alpha: 1),
                        NSColor(calibratedWhite: 0.79, alpha: 1)])!.draw(in: body, angle: -90)

    let lipRect = NSRect(x: bodyRect.minX, y: bodyRect.minY, width: bodyRect.width, height: 190)
    let lip = NSBezierPath(roundedRect: lipRect, xRadius: 92, yRadius: 92)
    NSGradient(colors: [NSColor(calibratedWhite: 0.72, alpha: 1),
                        NSColor(calibratedWhite: 0.88, alpha: 1)])!.draw(in: lip, angle: -90)
    NSColor(calibratedWhite: 0.48, alpha: 0.7).setStroke()
    lip.lineWidth = 3
    lip.stroke()

    appIcon.draw(in: NSRect(x: 244, y: 300, width: 536, height: 536), from: .zero,
                 operation: .sourceOver, fraction: 1, respectFlipped: true,
                 hints: [.interpolation: NSImageInterpolation.high])

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, pixels) in variants {
    try render(pixels: pixels).write(to: URL(fileURLWithPath: iconsetPath).appendingPathComponent(name))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetPath, "-o", outputPath]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("wrote \(outputPath)")

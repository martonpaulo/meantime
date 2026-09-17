// Renders the app-icon sizes each website slot actually needs. Deterministic:
// same input, same bytes.
//
//   swift scripts/render-web-assets.swift
//
// The social card is not drawn here any more: it is HTML rendered by
// `make social-card` from design/social-card/social-card.html, like every other
// product's card (the shared social card standard).
import AppKit

let iconURL = URL(fileURLWithPath: "site/assets/app-icon.png")

guard let icon = NSImage(contentsOf: iconURL) else {
    fatalError("missing \(iconURL.path)")
}

// The icon is shown in three slots. Serving the 512px original for a 36px slot
// downloads about fourteen times the pixels the page can use.
for side in [72, 280] {
    let scaled = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    scaled.size = NSSize(width: side, height: side)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: scaled)
    NSGraphicsContext.current?.imageInterpolation = .high
    icon.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
    NSGraphicsContext.restoreGraphicsState()
    let url = URL(fileURLWithPath: "site/assets/app-icon-\(side).png")
    try scaled.representation(using: .png, properties: [:])!.write(to: url)
    print("wrote \(url.path) at \(side)x\(side)")
}

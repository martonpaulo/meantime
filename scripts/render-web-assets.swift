// Renders the website's generated images: the 1200x630 social card the pages
// reference from og:image and twitter:image, and the app-icon sizes each page
// slot actually needs. Deterministic: same input, same bytes.
//
//   swift scripts/render-web-assets.swift
//
// The committed files are a little smaller than what this script writes:
// ImgBot re-encodes them losslessly after they land. Regenerating them is
// still correct, it just gives back those bytes until ImgBot runs again.
import AppKit

let size = NSSize(width: 1200, height: 630)
let output = URL(fileURLWithPath: "docs/assets/social-card.jpg")
let iconURL = URL(fileURLWithPath: "docs/assets/app-icon.png")

guard let icon = NSImage(contentsOf: iconURL) else {
    fatalError("missing \(iconURL.path)")
}

// Draw into an explicitly sized bitmap: locking focus on an NSImage would
// inherit this machine's Retina scale and produce a 2400x1260 file.
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
    fatalError("could not allocate the social card bitmap")
}
bitmap.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

// The app's own dark surface, so the card matches the product.
let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.11, alpha: 1),
    NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.18, alpha: 1),
])!
background.draw(in: NSRect(origin: .zero, size: size), angle: 68)

let iconSide: CGFloat = 224
icon.draw(in: NSRect(x: 96, y: (size.height - iconSide) / 2, width: iconSide, height: iconSide))

/// Draws one text block, positioned by its distance from the top edge. The
/// context is not flipped, so the rect is converted here rather than at every
/// call site.
@discardableResult
func draw(_ text: String, x: CGFloat, top: CGFloat, width: CGFloat, size fontSize: CGFloat,
          weight: NSFont.Weight, color: NSColor) -> CGFloat {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineHeightMultiple = 1.08
    let attributed = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph,
    ])
    let bounds = attributed.boundingRect(
        with: NSSize(width: width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin])
    let height = ceil(bounds.height)
    attributed.draw(with: NSRect(x: x, y: size.height - top - height, width: width, height: height),
                    options: [.usesLineFragmentOrigin])
    return height
}

let textLeft: CGFloat = 384
let textWidth = size.width - textLeft - 96
var cursor: CGFloat = 168
cursor += draw("Meantime", x: textLeft, top: cursor, width: textWidth, size: 40,
               weight: .semibold, color: NSColor(calibratedWhite: 0.60, alpha: 1)) + 18
cursor += draw("World clocks in your menu bar.", x: textLeft, top: cursor, width: textWidth,
               size: 60, weight: .bold, color: .white) + 26
draw("Scheduled clocks, a quick calendar, and time travel. Native, fast, private.",
     x: textLeft, top: cursor, width: textWidth, size: 28, weight: .regular,
     color: NSColor(calibratedWhite: 0.70, alpha: 1))

NSGraphicsContext.restoreGraphicsState()

// JPEG, not PNG: the card is a gradient behind text, where PNG cost 669 KB and
// a high-quality JPEG costs a fraction of that. Social crawlers all read JPEG.
guard let jpeg = bitmap.representation(using: .jpeg,
                                       properties: [.compressionFactor: 0.9]) else {
    fatalError("could not encode the social card")
}
try jpeg.write(to: output)
print("wrote \(output.path) at \(Int(size.width))x\(Int(size.height))")

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
    let url = URL(fileURLWithPath: "docs/assets/app-icon-\(side).png")
    try scaled.representation(using: .png, properties: [:])!.write(to: url)
    print("wrote \(url.path) at \(side)x\(side)")
}

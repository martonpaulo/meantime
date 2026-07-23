import AppKit

/// Builds the attributed title for a text menu-bar item. Time uses monospaced
/// digits so the item never changes width as it ticks, and the emoji-to-time gap
/// honors the user's element-spacing preference.
enum StatusItemTitle {
    /// One combined status item showing several clocks: "🇺🇸 7PM  🇧🇷 8PM".
    /// The inter-clock gap scales with the element-spacing preference.
    static func combined(entries: [(adornment: String?, time: String)], separator: String,
                         textSize: CGFloat, spacing: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, entry) in entries.enumerated() {
            if index > 0 {
                let separatorText = separator.isEmpty ? " " : " \(separator) "
                result.append(run(separatorText, font: NSFont.systemFont(ofSize: textSize),
                                  trailingKern: spacing))
            }
            result.append(attributed(adornment: entry.adornment, time: entry.time,
                                     textSize: textSize, spacing: spacing))
        }
        return result
    }

    static func attributed(adornment: String?, time: String,
                           textSize: CGFloat, spacing: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()

        if let adornment, !adornment.isEmpty {
            // The gap belongs after the adornment, not between its letters, so a
            // multi-character leading text ("br") reads as one word rather than "b r".
            result.append(run(adornment, font: NSFont.systemFont(ofSize: textSize),
                              trailingKern: spacing + Token.Space.xxs))
        }

        result.append(NSAttributedString(string: time, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: textSize, weight: .regular),
        ]))
        return result
    }

    /// A run whose spacing lives only after its last glyph, so kerning never spreads
    /// the characters of a multi-letter adornment or separator.
    private static func run(_ string: String, font: NSFont,
                            trailingKern: CGFloat) -> NSAttributedString {
        let piece = NSMutableAttributedString(string: string, attributes: [.font: font])
        let length = (string as NSString).length
        if length > 0 {
            piece.addAttribute(.kern, value: trailingKern,
                               range: NSRange(location: length - 1, length: 1))
        }
        return piece
    }
}

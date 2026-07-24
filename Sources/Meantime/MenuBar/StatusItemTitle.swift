import AppKit

/// Builds the attributed title for a text menu-bar item. Time uses monospaced
/// digits so the item never changes width as it ticks, and the leading-item gap
/// honors the user's element-spacing preference.
enum StatusItemTitle {
    /// One combined status item showing several clocks: "🇺🇸 7PM  🇧🇷 8PM".
    /// The inter-clock gap scales with the element-spacing preference.
    static func combined(entries: [(adornment: String?, adornmentIsText: Bool, time: String)],
                         separator: String, textSize: CGFloat, spacing: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, entry) in entries.enumerated() {
            if index > 0 {
                let separatorText = separator.isEmpty ? " " : " \(separator) "
                result.append(run(separatorText, font: NSFont.systemFont(ofSize: textSize),
                                  trailingKern: spacing))
            }
            result.append(attributed(adornment: entry.adornment, adornmentIsText: entry.adornmentIsText,
                                     time: entry.time, textSize: textSize, spacing: spacing))
        }
        return result
    }

    static func attributed(adornment: String?, adornmentIsText: Bool, time: String,
                           textSize: CGFloat, spacing: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = NSFont.systemFont(ofSize: textSize)

        if let adornment, !adornment.isEmpty {
            if adornmentIsText {
                // A text leading item has no built-in side bearing, so the old
                // space glyph plus kern read as an oversized gap after it. Carry
                // the whole gap as trailing kern on the text itself (safe, since
                // there is no emoji cluster to split), sized to the spacing
                // preference with a small floor so the time never touches it.
                result.append(run(adornment, font: font,
                                  trailingKern: max(spacing, Token.Space.xxs)))
            } else {
                // A flag or emoji is one grapheme cluster; kerning inside it lands
                // within a regional-indicator pair and splits it into boxed
                // letters. Keep the gap as a separate spacer run after the cluster.
                result.append(NSAttributedString(
                    string: adornment, attributes: [.font: font]))
                result.append(NSAttributedString(string: " ", attributes: [
                    .font: font,
                    .kern: spacing,
                ]))
            }
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

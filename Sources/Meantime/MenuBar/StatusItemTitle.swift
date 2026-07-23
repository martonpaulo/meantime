import AppKit

/// Builds the attributed title for a text menu-bar item. Time uses monospaced
/// digits so the item never changes width as it ticks, and the emoji-to-time gap
/// honors the user's element-spacing preference.
enum StatusItemTitle {
    /// One combined status item showing several clocks: "🇺🇸 7PM  🇧🇷 8PM".
    /// The inter-clock gap scales with the element-spacing preference.
    static func combined(entries: [(emoji: String?, time: String)],
                         textSize: CGFloat, spacing: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, entry) in entries.enumerated() {
            if index > 0 {
                let gap: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: textSize),
                    .kern: spacing + Token.Space.sm,
                ]
                result.append(NSAttributedString(string: " ", attributes: gap))
            }
            result.append(attributed(emoji: entry.emoji, time: entry.time,
                                     textSize: textSize, spacing: spacing))
        }
        return result
    }

    static func attributed(emoji: String?, time: String, textSize: CGFloat, spacing: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()

        if let emoji, !emoji.isEmpty {
            // Kerning after the emoji is the gap; a small base keeps it legible at 0.
            let emojiAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: textSize),
                .kern: spacing + Token.Space.xxs,
            ]
            result.append(NSAttributedString(string: emoji, attributes: emojiAttributes))
        }

        result.append(NSAttributedString(string: time, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: textSize, weight: .regular),
        ]))
        return result
    }
}

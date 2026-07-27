import SwiftUI

/// The single source of truth for every visual constant. Views must read from
/// here: no hardcoded sizes, insets, radii, or colors. Names are semantic so
/// intent survives redesigns.
enum Token {
    /// Spacing scale (points).
    enum Space {
        static let xxs: CGFloat = 2
        static let xxxs: CGFloat = 1
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    /// Corner radii (points).
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        /// Menu-bar panel corners (matches system menu panels).
        static let panel: CGFloat = 12
    }

    /// Fixed dimensions (points).
    enum Size {
        static let panelWidth: CGFloat = 420
        static let panelClockListMaxHeight: CGFloat = 216
        static let rowMinHeight: CGFloat = 46
        static let analogClock: CGFloat = 18
        static let hitTarget: CGFloat = 32
        static let statusItemMaxWidth: CGFloat = 260
        /// Stable content size shared by every Settings pane.
        static let paneWidth: CGFloat = 560
        static let paneHeight: CGFloat = 520
        static let aboutIcon: CGFloat = 64
        /// Gap between the menu bar and the anchored panel.
        static let panelGap: CGFloat = 5
        /// Screen-edge margin the panel never crosses.
        static let screenMargin: CGFloat = 8
        /// Calendar day-cell height and selection-circle diameter.
        static let calendarCell: CGFloat = 36
        static let calendarSelection: CGFloat = 31
        static let panelTimeBoost: CGFloat = 3
        /// Fixed icon column in panel action rows, so labels align.
        static let actionIconColumn: CGFloat = 16
        static let adornmentColumn: CGFloat = 22
        /// Weekday toggle in the schedule day picker: wide enough that the seven
        /// buttons form an even row whatever the locale's symbols are.
        static let dayToggle: CGFloat = 22
        static let hairline: CGFloat = 0.5
        static let selectionStroke: CGFloat = 1.5
    }

    /// Typography. Time uses monospaced digits so it never jitters as it ticks.
    enum Font {
        static func time(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .regular).monospacedDigit()
        }

        static let label = SwiftUI.Font.headline
        static let secondary = SwiftUI.Font.callout
        static let sectionTitle = SwiftUI.Font.caption.weight(.semibold)
        static let action = SwiftUI.Font.body
        static let calendarDay = SwiftUI.Font.body
        static let calendarNavigation = SwiftUI.Font.body.weight(.medium)
    }

    /// Semantic colors, all derived from system materials so light/dark and
    /// accessibility contrast settings are honored automatically.
    enum Color {
        static let primaryText = SwiftUI.Color.primary
        static let secondaryText = SwiftUI.Color.secondary
        static let accent = SwiftUI.Color.accentColor
        static let rowHighlight = SwiftUI.Color.primary.opacity(0.06)
        /// Subtle fill behind a compact editable control (the time field), so it
        /// reads as one tidy pill instead of the default stepper bezel.
        static let controlFill = SwiftUI.Color.primary.opacity(0.08)
        static let separator = SwiftUI.Color(nsColor: .separatorColor)
        static let hairlineSeparator = separator.opacity(0.5)
        static let subordinateText = secondaryText.opacity(0.5)
        static let weekendText = SwiftUI.Color(nsColor: .systemBlue).opacity(0.85)
        static let errorText = SwiftUI.Color(nsColor: .systemRed)
        /// Draws attention to a pending, not-yet-saved change (unsaved badge).
        static let attention = SwiftUI.Color(nsColor: .systemOrange)
        static let previewBackground = SwiftUI.Color(nsColor: .controlBackgroundColor)
    }

    /// Animation used for lightweight state changes (never for the ticking time).
    enum Motion {
        static let quick = Animation.easeOut(duration: 0.15)
    }
}

/// Icon + text with a fixed icon column, so every action row in the panel
/// (time travel, footer buttons) aligns on the same grid.
struct PanelActionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Token.Space.sm) {
            configuration.icon
                .frame(width: Token.Size.actionIconColumn, alignment: .center)
            configuration.title
        }
    }
}

import SwiftUI

/// The single source of truth for every visual constant. Views must read from
/// here — no hardcoded sizes, insets, radii, or colors. Names are semantic so
/// intent survives redesigns.
enum Token {
    /// Spacing scale (points).
    enum Space {
        static let xxs: CGFloat = 2
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
        /// Menu-bar dropdown panel corners (matches system menu panels).
        static let panel: CGFloat = 12
    }

    /// Fixed dimensions (points).
    enum Size {
        static let panelWidth: CGFloat = 320
        static let rowMinHeight: CGFloat = 28
        static let analogClock: CGFloat = 18
        static let hitTarget: CGFloat = 22
        /// Width of every settings pane (windowhop-style fixed panes).
        static let paneWidth: CGFloat = 560
        static let editorWidth: CGFloat = 440
        /// Gap between the menu bar and the anchored panel.
        static let panelGap: CGFloat = 5
        /// Screen-edge margin the panel never crosses.
        static let screenMargin: CGFloat = 8
        /// Calendar day-cell height and selection-circle diameter.
        static let calendarCell: CGFloat = 27
        static let calendarSelection: CGFloat = 24
        /// Fixed icon column in panel action rows, so labels align.
        static let actionIconColumn: CGFloat = 16
        static let adornmentColumn: CGFloat = 22
    }

    /// Typography. Time uses monospaced digits so it never jitters as it ticks.
    enum Font {
        static func time(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .regular).monospacedDigit()
        }

        static let label = SwiftUI.Font.system(size: 13, weight: .regular)
        static let secondary = SwiftUI.Font.system(size: 11, weight: .regular)
        static let sectionTitle = SwiftUI.Font.system(size: 11, weight: .semibold)
        static let action = SwiftUI.Font.system(size: 13, weight: .regular)
        static let calendarDay = SwiftUI.Font.system(size: 12, weight: .regular)
        static let calendarNavigation = SwiftUI.Font.system(size: 11, weight: .semibold)
    }

    /// Semantic colors, all derived from system materials so light/dark and
    /// accessibility contrast settings are honored automatically.
    enum Color {
        static let primaryText = SwiftUI.Color.primary
        static let secondaryText = SwiftUI.Color.secondary
        static let accent = SwiftUI.Color.accentColor
        static let rowHighlight = SwiftUI.Color.primary.opacity(0.06)
        static let separator = SwiftUI.Color(nsColor: .separatorColor)
        static let weekendText = SwiftUI.Color(nsColor: .systemRed)
        static let errorText = SwiftUI.Color(nsColor: .systemRed)
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

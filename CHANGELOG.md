# Changelog

All notable changes to Meantime are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Scheduled hours pick their own days of the week, so one clock can follow office hours Monday to Friday and different hours at the weekend. Days are read in the clock's own time zone, an overnight window belongs to the day it starts on, and Add Hours offers the days no window has claimed yet.

### Fixed

- The segmented time editor no longer draws its digits a line below the field: an empty text-field label was reserving vertical space, pushing the hours and minutes outside the control's background.
- A scheduled clock now flips exactly on the wall-clock edge on daylight-saving days; transition times were computed from elapsed minutes since midnight, which drifted by an hour after a change.

## [1.2.3] - 2026-07-24

### Fixed

- The time-zone search field reliably keeps the first keystrokes: it now grabs focus once, when it enters the window, so a re-render from the first character can no longer re-install the field editor and clear what was typed.
- Time travel no longer shows the "Previewing…" state when the chosen time is the current minute; the row returns to its plain appearance and the minute-granular check keeps it from flickering across the minute boundary.

### Changed

- Time entry (time travel and scheduled hours) uses a fixed-width, locale-aware segmented editor: `[h]:[mm]` on a 24-hour clock and `[h]:[mm] [AM/PM]` on a 12-hour one. Each numeric segment takes one or two digits, invalid or incomplete input reverts on commit, and values normalize sensibly (minutes into 00–59, and `15` into `3 PM` on a 12-hour clock).
- The Add-clock time-zone picker's back control now sits inline with the title instead of on its own row, so the title, search field, and list are no longer pushed down.
- The gap between a text leading item and its time in the menu bar is tighter, matching the element-spacing preference instead of adding an extra space glyph on top of it.

## [1.2.2] - 2026-07-24

### Fixed

- Menu-bar leading flags no longer split into boxed letters; the element-spacing gap is applied after the adornment rather than inside its regional-indicator cluster.
- The time-zone search field no longer drops the first keystrokes; its value is synced only while it is not being edited.

### Changed

- Double-click a clock row to open its editor, alongside the disclosure chevron and single-click selection.
- The Add-clock time-zone picker uses the same top-left back control as the editor.
- The clock editor no longer shows a redundant "Preview" label.
- The website format builder keeps the live preview and pattern input pinned while the token reference scrolls.
- Documentation screenshots are framed on a soft backdrop with a drop shadow instead of a flat opaque window.

## [1.2.1] - 2026-07-23

### Fixed

- Scheduled menu-bar hours now edit in the clock's own zone, so a typed time is stored and applied as that wall-clock time rather than shifted by the editor's local offset.
- Single-click again selects a clock row; the removed double-click gesture no longer swallows the selection.
- Menu-bar leading text no longer spreads its letters; the element-spacing gap sits only after the leading item.
- Reopening Settings returns to the Clocks list instead of resuming a half-finished edit.
- The Clocks list Return and Delete shortcuts are scoped to the list, so a stray key no longer edits or removes a row behind an open picker or editor.
- Hardened the clock editor against a draft force-unwrap that could close the app mid-dialog.

### Changed

- Time entry for schedules and time travel uses one compact custom field instead of the stepper control.
- Each clock row has a direct menu-bar visibility switch and a disclosure chevron that opens its editor.
- The clock editor gained a labeled back control, a clearer unsaved-changes badge, and more room around the preview.
- The calendar Today action is disabled while the calendar is already on the current day.
- Entering time travel no longer resizes the panel.
- The updates toggle reflects Sparkle's state on first paint instead of flipping after appearing.
- Documentation screenshots render each Settings pane without the tab toolbar, so the selected item is no longer a blank block.

## [1.2.0] - 2026-07-23

### Added

- Discoverable per-clock removal controls with destructive confirmation.
- Per-clock country flag, custom emoji, custom text, or no leading item.
- Save-gated live previews, per-clock Restore Defaults, format presets, and a configurable combined-item separator.
- Calendar year navigation, labeled Today action, stable six-week layout, and locale-aware weekend styling.
- UTC, GMT, fixed-offset IANA zones, localized zone-name search, standard Help menus, and a packaged English localization base.
- Native selectable clock management with add, remove, reorder, context-menu, and keyboard actions.

### Changed

- The menu-bar panel now uses native popover material, a roomier 420-point layout, larger type, and a consistent spacing hierarchy.
- The panel now bounds long clock lists, exposes the full active time-travel date, and distinguishes weekends with restrained blue text.
- Clock creation and editing now stay inside the Clocks pane with a transactional draft, fixed actions, inline validation, and unsaved-change confirmation.
- Appearance settings now persist as one typed value and one observable write.
- Format settings now rely on the real menu bar for immediate feedback and no longer show a redundant preview row.
- Scrollable settings keep native scrolling and keyboard behavior without a persistent visual scroll indicator.
- The website now has consistent navigation, corrected spacing, and a grouped UTS-35 builder with a fixed illustrative date, literal text, and official advanced documentation.
- Documentation screenshots now render offscreen at 2x without taking focus, opening windows, or requiring Screen Recording access.
- User-facing copy is shorter and consistent across the app and website, with no em dash character.

### Fixed

- The calendar now respects the time zone of its supplied calendar, including month boundaries.
- Returning to Today also clears a previously selected day instead of silently previewing it.
- Clock rows no longer claim a scheduled clock is visible “now” from stale, unscheduled view state.
- Public pages no longer claim a release is notarized while Apple's submission is still pending.
- README and website no longer present screenshots of settings removed by the current interface.
- Removed the permanently unavailable 1.0.0 enclosure from the Sparkle appcast.
- Equal, duplicate, and overlapping scheduled windows are rejected; invalid legacy rows no longer create false scheduler wakes.
- User-authored menu-bar text now has grapheme-safe limits, and status items/panel rows truncate visually without losing their full accessibility text.
- The guided website builder now rejects every mixed uppercase-hour/day-period combination while ignoring quoted literals.

## [1.1.0] - 2026-07-23

### Added

- **Quick month calendar** in the panel: check which weekday any date falls
  on, browse months, and pick a day to preview it across every clock.
- **Typed time travel**: type a time (and pick a day) instead of dragging a
  slider; one click returns to now.
- **Scheduled clocks**: show a clock in the menu bar only during chosen hours
  *in its own time zone* (e.g. New York 8–12 and 13–17 NY time); it hides
  itself outside those windows and stays in the panel.
- **Combined menu-bar layout**: every clock in a single status item
  (`🇺🇸 7PM 🇧🇷 8PM`), or one item per clock as before.
- **GMT offset and day captions** on panel rows ("GMT−3 · Yesterday").
- Explicit up/down reordering buttons for clocks (drag still works).
- A grouped, searchable Add Clock sheet with live GMT offsets.
- An [interactive format builder](https://martonpaulo.github.io/meantime/format.html)
  on the website, linked from Format settings.
- A proper main menu: ⌘W closes windows, ⌘, opens Settings, and text fields
  gain the standard Edit shortcuts.

### Changed

- **All-new panel**: anchored flush under the menu bar with no arrow, popover
  material, complete times in rows, and direct Settings/Quit footer actions.
- **All-new Settings**: native toolbar panes (System Settings style) for
  Clocks, Format, General, and About; clock editing moved to a focused sheet.
- **New app icon**: a minimal, luminous take drawn for the modern macOS icon
  language, with matching installer artwork.
- Panel rows always show a complete time, even when the menu bar shows only
  the hour.

### Fixed

- Explicit hour patterns (`HH`, `H`) are no longer rewritten to 12-hour by the
  system's AM/PM preference: a 24-hour pattern now always renders 24-hour.
- The panel no longer opens detached below the menu bar or at zero size.

## [1.0.0] - 2026-07-22

### Added

- World clocks in the menu bar: pin any time zone, or keep it panel-only.
- Three per-clock menu-bar styles: time only, flag + time, and analog face.
- Time-travel preview across all clocks.
- Custom labels and emoji per clock, with region-flag and city-name defaults.
- Customizable time format with live examples, or the system default.
- Adjustable menu-bar text size and element spacing.
- Open-at-login via the modern login-item service.
- Energy-aware, boundary-aligned updates that never wake more often than the
  displayed precision requires, with instant re-sync on wake/clock/zone changes.
- Sparkle-based automatic updates for the direct-download build.

[1.2.0]: https://github.com/martonpaulo/meantime/releases/tag/v1.2.0
[1.1.0]: https://github.com/martonpaulo/meantime/releases/tag/v1.1.0
[1.0.0]: https://github.com/martonpaulo/meantime/releases/tag/v1.0.0

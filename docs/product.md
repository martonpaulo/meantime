# Meantime

Meantime shows world clocks in the macOS menu bar. It is a native, accessory
(menu-bar-only) app for Mac users coordinating work or personal plans across
multiple time zones. It replaces repeated time-zone lookups with a glance and
a transient preview of another moment.

Success means users can read the correct time in each chosen zone, see scheduled
clocks appear at the intended local boundaries, and preview a date/time without
changing saved clocks. Correctness follows the system clock and user calendar;
idle operation does no unnecessary work. These are observable product contracts,
not claims that every current implementation path already satisfies them.

- Add a clock for any time zone; give it a custom label and choose a country
  flag, custom emoji, custom text, or no leading item.
- Show any clock directly in the menu bar (its own item, or all clocks combined
  into one), keep it panel-only, or schedule the days and hours, in the clock's
  own zone, during which it appears.
- The dropdown panel is a glance surface: complete times with GMT/day captions,
  a quick month calendar, and typed time travel (pick a day, type a time) that
  previews the moment across every clock and resets on close.
- The time format starts with common presets and supports any custom Unicode
  (UTS-35) pattern with a live preview; the website ships an interactive
  grouped builder. The Mac's system format is the default.

**Simple by design.** No accounts, no sync, no widgets, no analytics, no
telemetry. The only network activity permitted is Sparkle update checks in the
direct-download build. Do not add cloud services, background jobs, or content
polling. Keep the surface small; new capability is a deliberate product change,
not a default.

Accounts, sync, analytics, and telemetry are excluded to keep personal clock
preferences local and avoid a service dependency. Widgets and unrelated calendar
management are excluded to keep the product focused on its menu-bar glance
surface. The website helps users understand and configure Meantime; it is not a
second hosted clock service.

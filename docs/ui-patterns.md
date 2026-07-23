# UI patterns

The contract every Meantime view follows. New UI reuses these; a genuinely new
pattern is confirmed and documented before it lands (see the pattern-break
protocol in `AGENTS.md`).

## Design tokens are the only source of visual constants

Spacing, padding, sizes, corner radii, font sizes/weights, colors, and animation
durations come from the design-token namespace. Views never hardcode a magic
number or a raw color. Prefer semantic token names (what it's for) over raw
values (what it is), so a redesign changes one place.

## Compose, don't duplicate

Anything that looks the same twice becomes one small view assembled by
composition — a clock row, a preset option, a labeled slider. One definition,
reused in the panel and settings.

## Native semantics first

- Use native controls and containers (`Form`, `List`, `LabeledContent`,
  `Slider`, `Menu`, `Toggle`, `Picker`). Reach for manual stacks only when a
  native container doesn't fit.
- Preserve keyboard navigation, focus, hover/pressed/disabled states, Dynamic
  Type, contrast, reduced motion, and safe areas.
- Don't replace a native control with custom drawing unless there's clear
  product value and accessibility is preserved (the analog menu-bar face is the
  one deliberate exception, and it ships as a template image so the system tints
  it for light/dark).

## Views render prepared state

Views draw values that a formatter, view model, or controller already computed.
Formatting, day-difference captions, sorting, and filtering happen outside
`body`; `body` stays cheap and never blocks the main actor.

## Time text

Time is always drawn with monospaced digits so an item never changes width as it
ticks.

## Surface conventions

- **Menu-bar panel**: a borderless, popover-material window anchored flush
  under its status item (no arrow, `panel` corner radius, hairline border). It
  opens unfocused — no control grabs a focus ring on a glance surface. Sections
  are separated by hairline dividers with the panel's standard rhythm; action
  rows share one label style with a fixed icon column so everything aligns;
  actions are **direct** (icon + text footer buttons) — never a nested menu
  inside a menu-bar dropdown. ⌘W and Escape close it like any transient window.
- **Sheets and transient windows** always answer ⌘W and Escape as dismissal.
  Unlimited content owns a bounded native scroll area; primary actions stay in
  a fixed footer.
- **Settings**: a toolbar-style tab window (System Settings look) with one
  stable content size across panes. Grouped forms scroll inside that surface;
  clock management uses a native selectable list and bottom action bar.
- **Editing a list item** happens in a sheet with an always-visible preview,
  grouped scrolling form, and explicit Cancel/Save actions. New items are also
  drafts and use Add Clock. Leaving a dirty editor offers commit, discard, and
  cancel.
- **Choices render as their result**: format options show live samples of the
  exact fragment they contribute; sliders show their current value; previews
  update as you type.
- **Hover states** on custom rows use the shared row-highlight token; buttons in
  quiet surfaces brighten from secondary to primary on hover.
- **Destructive flows** always name the affected data and use a destructive
  action role. Rare irreversible removal uses a native alert with an explicit
  Cancel action; restore/discard choices use `confirmationDialog`.

## Before changing UI

Briefly critique what's there, then plan layout, controls, every interaction
state, accessibility, and validation before editing.

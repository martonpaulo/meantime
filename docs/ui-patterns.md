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

## Before changing UI

Briefly critique what's there, then plan layout, controls, every interaction
state, accessibility, and validation before editing.

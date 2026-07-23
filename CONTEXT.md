# Meantime: Domain Glossary

Canonical vocabulary for the app. Keep entries limited to domain terms, states,
and rules. This is not a specification.

- **Clock**: a user-configured reference to one time zone, with a label, a
  leading-item choice, a menu-bar presentation, and whether it is pinned.
- **Time zone**: an IANA identifier (e.g. `America/Sao_Paulo`) resolved through
  the system. The source of truth for a clock's offset, including DST.
- **Label**: the human name shown for a clock. Defaults to a humanized city
  from the identifier; user-overridable.
- **Leading item / adornment**: optional content before a clock. Defaults to
  the time zone's region flag; choices are flag, custom emoji, custom text, or none.
- **Pinned**: a clock shown in the menu bar (subject to its schedule). Unpinned
  clocks appear only inside the panel.
- **Menu-bar layout**: *individual* (each shown clock gets its own status item)
  or *combined* (every shown clock rides one status item). Combined items use
  a configurable separator whose default is `/`; empty means spacing only.
- **Active window / schedule**: daily start–end minutes, evaluated in the
  clock's own time zone, during which a pinned clock occupies the menu bar.
  No windows = always shown. Outside its windows the clock stays in the panel.
- **Panel**: the dropdown anchored under a menu-bar item: complete-time clock
  rows, the month calendar, typed time travel, and direct Settings/Quit actions.
- **Menu-bar presentation / render mode**: how a pinned clock draws in the menu
  bar: time only, leading item + time, or an analog face (no text). In combined
  layout an analog choice falls back to its textual form.
- **Time format**: either *system*, a common preset, or a *custom* Unicode
  (UTS-35) pattern. Presets resolve to the same persisted pattern contract; the
  website's interactive **format builder** assembles patterns visually.
  Explicit hour fields always defeat the system 12/24-hour rewrite.
- **Settings preview**: transient clock/appearance values rendered in the real
  menu bar while editing. Only Save copies them into durable Preferences.
- **Time travel**: a transient preview instant: a day picked on the calendar
  and/or a typed time, applied uniformly to every clock. Resets whenever the
  panel opens; panel rows always show complete times while previewing.
- **Granularity**: the coarsest time field any visible clock displays. Governs
  how often the app updates (seconds, minutes, or hours). See the Time & Energy
  contract in `AGENTS.md`.
- **Boundary**: the next instant the displayed granularity changes (next
  minute/hour). Updates are scheduled to boundaries, not fixed intervals.

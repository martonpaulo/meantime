# Meantime — Domain Glossary

Canonical vocabulary for the app. Keep entries limited to domain terms, states,
and rules. This is not a specification.

- **Clock** — a user-configured reference to one time zone, with a label, an
  emoji, a menu-bar presentation, and whether it is pinned to the menu bar.
- **Time zone** — an IANA identifier (e.g. `America/Sao_Paulo`) resolved through
  the system. The source of truth for a clock's offset, including DST.
- **Label** — the human name shown for a clock. Defaults to a humanized city
  from the identifier; user-overridable.
- **Emoji** — the glyph shown before a clock. Defaults to the flag of the time
  zone's region; user-overridable to any emoji.
- **Pinned** — a clock that has its own dedicated menu-bar item. Unpinned clocks
  appear only inside the panel.
- **Panel** — the dropdown opened from a menu-bar item: the full list of clocks
  plus the time-travel control and app actions.
- **Menu-bar presentation / render mode** — how a pinned clock draws in the menu
  bar: time only, flag + time, or clock glyph only (an icon, no text).
- **Time format** — either *system* (follows the Mac's locale and 12/24-hour
  setting) or a *custom* Unicode (UTS-35) pattern. Presets provide common
  patterns with live examples; reset returns to system.
- **Time travel** — a temporary offset applied uniformly to every clock so the
  user can preview a future/past moment across all zones. Non-persistent;
  releasing returns to *now*.
- **Granularity** — the coarsest time field any visible clock displays. Governs
  how often the app updates (seconds, minutes, or hours). See the Time & Energy
  contract in `AGENTS.md`.
- **Boundary** — the next instant the displayed granularity changes (next
  minute/hour). Updates are scheduled to boundaries, not fixed intervals.

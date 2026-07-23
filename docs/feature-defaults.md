# Feature defaults and configurability

Every user-facing behavior states its default and whether it is configurable.
Defaults live in one place in the preferences layer; this table is the human
summary. Reset ("Restore Defaults") returns every configurable value below to
its default and touches nothing else (not the login item, not identity).

| Behavior | Default | Configurable? | Notes |
| --- | --- | --- | --- |
| Clocks | one clock for the Mac's own zone | yes | every system IANA identifier, including UTC/GMT/fixed offsets; add / remove / reorder |
| Clock label | humanized city from the zone | yes | empty falls back to the default; maximum 40 grapheme clusters |
| Clock leading item | region flag from the zone | yes | country flag · one custom emoji grapheme · custom text up to 8 graphemes · none; values remain separate when switching |
| Menu-bar style (per clock) | leading item + time | yes | time only · leading item + time · analog face |
| Pinned to menu bar | on | yes | off ⇒ shown in the panel only |
| Menu-bar layout | one item per clock | yes | or all clocks combined into a single item; analog falls back to leading item + time when combined |
| Combined-item separator | `/` | yes | up to 3 graphemes; empty means spacing only |
| Scheduled hours (per clock) | none (always shown) | yes | own-zone daily windows; end before start means overnight; equal, duplicate, and overlapping rows are invalid |
| Time format | system | yes | preset-first; Custom accepts structurally valid Unicode (UTS-35), quoted literal text, and up to 256 graphemes |
| Menu-bar text size | 13 pt | yes | 10–18 pt |
| Element spacing | 4 pt | yes | 0–12 pt |
| Open at login | off | yes | owned by the system login-item service, not stored in preferences |
| Automatic update checks | on (release builds) | yes | persisted by Sparkle itself; manual check always available |
| Panel row time | complete time (min. minutes) | no | a coarser menu-bar format falls back to system short time in the panel: a glance surface must answer "what time is it" fully |
| Time-travel preview | now | transient | day + typed time; resets every time the panel opens; never persisted |
| Calendar browsing | current month | transient | six stable week rows, locale-aware weekends, month/year navigation, labeled Today action |
| Update cadence | boundary-aligned to the coarsest visible unit, plus schedule transitions | no | correctness + energy behavior; a single valid outcome |
| Time source | system clock | no | never a private counter |

## Intentionally non-configurable

- **Update cadence and the time source** have one correct behavior; exposing
  them would only let a user make the clock wrong or wasteful.
- **Panel completeness**: hour-only is a menu-bar economy, not an answer; the
  panel exists to give the full time.
- **Explicit hour patterns defeat the system 12/24 override**: an explicit
  `HH` must never silently render as `h a`.

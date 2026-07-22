# Feature defaults and configurability

Every user-facing behavior states its default and whether it is configurable.
Defaults live in one place in the preferences layer; this table is the human
summary. Reset ("Restore Defaults") returns every configurable value below to
its default and touches nothing else (not the login item, not identity).

| Behavior | Default | Configurable? | Notes |
| --- | --- | --- | --- |
| Clocks | one clock for the Mac's own zone | yes | add / remove / reorder |
| Clock label | humanized city from the zone | yes | empty falls back to the default |
| Clock emoji | region flag from the zone | yes | empty falls back to the flag; any emoji allowed |
| Menu-bar style (per clock) | flag + time | yes | time only · flag + time · analog face |
| Pinned to menu bar | on | yes | off ⇒ shown in the panel only |
| Time format | system | yes | preset, any Unicode pattern, or reset to system |
| Menu-bar text size | 13 pt | yes | 10–18 pt |
| Element spacing | 4 pt | yes | 0–12 pt |
| Open at login | off | yes | owned by the system login-item service, not stored in preferences |
| Time-travel offset | now | transient | resets every time the panel opens; never persisted |
| Update cadence | boundary-aligned to the coarsest visible unit | no | correctness + energy behavior; a single valid outcome |
| Time source | system clock | no | never a private counter |

## Intentionally non-configurable

- **Update cadence and the time source** have one correct behavior; exposing
  them would only let a user make the clock wrong or wasteful.
- **Automatic update checks** are on in release builds (the app's only network
  activity); a manual "Check for Updates" is always available.

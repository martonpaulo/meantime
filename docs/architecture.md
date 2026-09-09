# Architecture

Meantime is a native macOS accessory app in two layers, described here by
responsibility rather than by file names (names drift; responsibilities don't).

## Layers

**Domain kit (pure).** Foundation-only logic with no UI imports: the clock
model, time formatting with cached formatters, region-flag and city-name
derivation, civil-day math, the update-cadence planner, and the typed
preferences contract. Every business rule lives here and is unit-tested.

**App surface.** The menu-bar controller, the SwiftUI panel and settings, the
lifecycle, the login item, and Sparkle. It consumes the kit and owns no business
rules of its own: views render prepared state.

The kit never imports SwiftUI, AppKit, or Sparkle (enforced by the validation
script). Sparkle is embedded only in the packaged app.

## Data flow

- **Preferences** is the single, observable durable source of truth. It
  persists committed changes write-through and seeds sensible defaults on
  first launch. A single app-surface settings preview temporarily overlays
  draft values for rendering in the status item and panel. Clock drafts commit
  once; format/layout/spacing form one typed appearance value and one persisted
  write. Cancel discards the overlay without touching durable state.
- The **menu-bar controller** observes committed preferences and the transient
  settings preview. When the set of pinned
  clocks changes it rebuilds status items; for lighter changes (label, emoji,
  size, format) it just refreshes titles, so dragging a slider never flickers
  the menu bar.
- A shared **time source** holds "now". The ticker advances it on each boundary,
  and both the AppKit status items and the SwiftUI panel read from it, so they
  always show the same instant.

## Time and energy

Correct time is non-negotiable; idle cost must be near zero.

- The only clock is the system clock, which macOS keeps NTP-synced. There is no
  private counter that could drift.
- The planner computes the coarsest field any *visible* clock shows
  (seconds/minutes/hours/day) and returns the earliest next boundary across all
  of them, taking each zone into account (fractional-hour offsets shift the hour
  boundary). Boundaries come from the calendar interval containing the instant,
  so a repeated local hour still moves forward. A single timer is armed to that
  absolute instant and re-armed on each fire: no fixed intervals, no per-item
  timers, no drift.
- Some output changes at instants no field boundary predicts: a localized day
  period (`a`, `b`, `B`) or a zone name that follows an offset transition. For
  those, and only when no finer field is present, the planner finds the change
  by comparing the cached formatter's own output at a small bounded candidate
  set. Nothing is scanned second by second.
- When nothing visible shows changing time, no timer runs.
- The ticker also refreshes immediately on system clock change, time-zone
  change, and wake from sleep.

## Threading

Everything user-facing runs on the main actor. The formatter is safe for
concurrent use (thread-safe cache; formatters are only read after configuration).
Concurrency boundaries are explicit and minimal, per Swift 6.

## Distribution

Direct download only: a notarized Developer ID DMG plus Sparkle auto-update via
an appcast hosted in this repository. Signing material never enters the repo.

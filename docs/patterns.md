# Meantime patterns

The rules this app's code, site and tests repeat, moved out of `AGENTS.md` when it took the
route map of the Workbench baseline ([#29](https://github.com/martonpaulo/meantime/issues/29)). `AGENTS.md` routes here before an
edit under `Sources/`, `Tests/` or `site/`. A change that breaks one of these patterns or
establishes a new one follows the pattern-break protocol below.

## Contents

- [Architecture (by responsibility)](#architecture-by-responsibility)
- [Design system](#design-system)
- [Time & Energy contract (the core differentiator)](#time--energy-contract-the-core-differentiator)
- [Feature defaults and configurability](#feature-defaults-and-configurability)
- [Conventions](#conventions)
- [Pattern-break protocol](#pattern-break-protocol)

## Architecture (by responsibility)

Two layers, kept apart:

1. **Domain kit**: pure logic with no AppKit/SwiftUI. Models, time formatting,
   flag and city derivation, tick-granularity math, and the preferences
   contract. All business rules live here **with unit tests**. Imports
   Foundation only.
2. **App surface**: the menu-bar controller, SwiftUI panel and settings,
   lifecycle, login item, and Sparkle. Consumes the domain kit; owns no
   business rules of its own.

Tests target the domain kit. Keep the SwiftPM structure standard (package
manifest at root, one library target for the kit, one executable for the app,
one test target). Do not add extra targets or top-level folders for symmetry.

## Design system

- **All visual constants come from design tokens**: spacing, padding, sizes,
  corner radii, font sizes/weights, colors, animation durations. No hardcoded
  magic numbers in views. Prefer semantic token names over raw values.
- **Compose, don't duplicate.** Anything that looks the same twice becomes one
  reusable view built by composition. A clock row, a format-preset chip, a
  labeled control: one definition, reused.
- **Respect the platform.** Preserve native semantics, keyboard navigation,
  focus, hover/pressed/disabled states, Dynamic Type, contrast, reduced
  motion, and safe areas. Follow the current macOS HIG and design language.
- Before any UI change, briefly critique the current UI, then plan layout,
  controls, states, accessibility, and validation.

## Time & Energy contract (the core differentiator)

- **Single time source:** the system clock (`Date`), which macOS keeps
  NTP-synced. Never maintain a private counter that can drift.
- **Per-target-zone formatting** through the shared formatter, with formatters
  cached per (time zone, pattern, locale). No formatter allocation on the hot
  path.
- **Granularity drives cadence.** Compute the coarsest field that any *visible*
  clock displays (seconds → minutes → hours). Schedule exactly one update
  aligned to the next boundary of that field; re-arm on each fire. If nothing
  visible shows time (e.g. all menu-bar items are glyph-only or hidden), run no
  timer at all.
- **Boundary alignment, not intervals.** Fire at the next real minute/hour
  boundary so the menu bar flips exactly on time with no accumulated drift.
- **Resync immediately** on system clock change, time-zone change, and wake
  from sleep. Correctness beats battery every time.

## Feature defaults and configurability

For every new user-facing behavior:

- Define its default explicitly.
- Decide whether it is user-configurable and record why. Prefer a setting when
  both states are legitimate preferences; do not add settings for bug fixes,
  mandatory accessibility behavior, or single-outcome details.
- Store defaults in one place (the preferences defaults). Do not duplicate
  fallback values in views, controllers, tests, or migrations.
- Persist configurable preferences through the typed preferences layer, which
  is the runtime source of truth.
- Preserve existing user choices on upgrade; migrate a stored value only when
  the old representation is invalid.
- Register every configurable preference so Restore Defaults resets it. Reset
  must not touch identity, permissions, or non-preference user data.

A missing configurability decision is a review failure.

## Conventions

- Conventional Commits. **English everywhere**: code, comments, docs, copy,
  errors, examples, file names.
- Comments state constraints the code cannot show (platform quirks, why a
  boundary exists), not narration of what the code already says.
- Human-readable code over cleverness. Small, well-named units.
- Search first; read the smallest useful chunk; reuse existing code, patterns,
  components, formatters, helpers, and Makefile targets before adding new ones.
- No new dependencies unless clearly required, justified, and consistent with a
  native, low-cost menu-bar app.
- Add or update focused tests only for changed behavior, regressions,
  persistence contracts, accessibility-critical flows, or validation-sensitive
  code. Avoid tests that mirror implementation details or duplicate coverage.

## Pattern-break protocol

This file is the source of truth for how Meantime is built. **If a task seems
to require breaking an established pattern**: introducing a second way to
format, a hardcoded dimension, a parallel persistence path, a new dependency, a
per-item timer, business logic in a view, or a new architectural layer;
**stop and confirm with the user before either forcing the change into the old
pattern or defining a new one.** Name the pattern in tension, the options, and
the tradeoff. Silent divergence is a defect. When a genuinely new pattern is
agreed, document it here in the same turn.

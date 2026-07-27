# Meantime — Agent Policy

Durable root policy for Meantime. Follow it for all coding, UI, documentation,
validation, packaging, git, and release-prep work in this repository. A more
specific `AGENTS.md` inside a subtree overrides this one for that subtree.

> This file documents **patterns and contracts**, not the current file layout.
> Describe responsibilities, not exact file or folder names — names drift, and
> stale structure docs are worse than none.

## Project identity and policy

Stable, one-time decisions. Change an established identifier, license,
visibility, branch policy, versioning model, localization strategy, landing-page
contract, or release policy only through an explicit task that describes the
migration and its downstream effects.

- Project and public name: `Meantime`
- Description: world clocks in your macOS menu bar — scheduled clocks, quick
  calendar, time travel. Native, fast, private.
- Repository: `martonpaulo/meantime` (public)
- Public identifiers: bundle `com.perso.meantime`; SwiftPM package `Meantime`,
  library target `MeantimeKit`, executable target `Meantime`
- Landing page: `https://martonpaulo.github.io/meantime/`, built from `docs/`
  in this repository and published by GitHub Pages
- License: `MIT`, © 2026 Marton Paulo
- Development language: English (code, comments, commits, filenames, tests,
  configuration, developer docs)
- Product copy: English only; source strings live in the app target, no
  additional locales ship. Dates, times, and weekday names always follow the
  user's own locale and calendar
- Branch policy: work only on `main`; never create, switch, or rename branches
- Commit policy: commit automatically on task completion, one concern per commit
- Push policy: push to `origin/main` automatically after committing
- Product versioning: user-visible SemVer, canonical in the app's
  `CFBundleShortVersionString` (with a derived numeric `CFBundleVersion`).
  Increments only during an explicitly requested release, which also updates
  `CHANGELOG.md`, tags `vX.Y.Z`, and regenerates the appcast. Ordinary tasks
  add to `## [Unreleased]` and never bump a version
- Delete branches after merge: enabled (bot PRs are the only branches)
- Release, signing, and secret storage: see **Distribution & signing** below

## Product

Meantime shows world clocks in the macOS menu bar. It is a native, accessory
(menu-bar-only) app.

- Add a clock for any time zone; give it a custom label and choose a country
  flag, custom emoji, custom text, or no leading item.
- Show any clock directly in the menu bar (its own item, or all clocks combined
  into one), keep it panel-only, or schedule the days and hours — in the clock's
  own zone — during which it appears.
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

## Build and validate

Prefer the smallest relevant check. Use `make` targets; do not hand-roll
equivalents.

- `make build` — debug build, must be warning-free.
- `make test` — unit tests (the pure domain kit).
- `make check` — build + test + repository invariants.
- `make run` — run the debug app from the terminal.
- `make icon` — regenerate the app icon.
- `make app` — Release `.app` (ad-hoc unless a signing identity is provided).
- `make dmg` — installer DMG with drag-to-Applications artwork.
- `make appcast` — regenerate the Sparkle appcast for a release.

Task logs and generated release artifacts live under `artifacts/` (gitignored).
Inspect a failed log before rerunning; never rerun an unchanged failing command.

## Hard rules

- **Public, stable Apple APIs only.** No private frameworks, no `_`-prefixed
  SPI, no beta-only behavior. Target the current stable OS (see Deployment).
- **Native first.** SwiftUI for the panel and settings; AppKit only where
  SwiftUI does not cover the surface (dynamic menu-bar status items). Do not
  replace native controls with custom UI unless there is clear product value
  and accessibility is preserved.
- **Correct time is non-negotiable, and idle cost must be near zero.** See the
  Time & Energy contract below. Never trade correctness for battery, and never
  wake more often than the coarsest visible format actually changes.
- **No polling or timers while nothing visible changes.** Drive updates from a
  single boundary-aligned scheduler and from system change notifications
  (wake, clock change, time-zone change). No per-item timers.
- **Keep business logic out of views.** Views render prepared state from a view
  model / controller / formatter. Keep expensive work out of SwiftUI `body`,
  and never block the main actor.
- **DRY.** One home for each rule: formatting, flag/label derivation, sorting,
  filtering, tick granularity, persistence, and copy lists. No parallel
  implementations of the same rule.
- **Swift 6 concurrency.** Explicit, minimal `@MainActor` / actor boundaries;
  do not regress concurrency safety.

## Architecture (by responsibility)

Two layers, kept apart:

1. **Domain kit** — pure logic with no AppKit/SwiftUI. Models, time formatting,
   flag and city derivation, tick-granularity math, and the preferences
   contract. All business rules live here **with unit tests**. Imports
   Foundation only.
2. **App surface** — the menu-bar controller, SwiftUI panel and settings,
   lifecycle, login item, and Sparkle. Consumes the domain kit; owns no
   business rules of its own.

Tests target the domain kit. Keep the SwiftPM structure standard (package
manifest at root, one library target for the kit, one executable for the app,
one test target). Do not add extra targets or top-level folders for symmetry.

## Design system

- **All visual constants come from design tokens** — spacing, padding, sizes,
  corner radii, font sizes/weights, colors, animation durations. No hardcoded
  magic numbers in views. Prefer semantic token names over raw values.
- **Compose, don't duplicate.** Anything that looks the same twice becomes one
  reusable view built by composition. A clock row, a format-preset chip, a
  labeled control — one definition, reused.
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

## Distribution & signing

- Distribution is **direct download only**: a notarized, stapled DMG signed
  with the stable Developer ID Application identity, plus Sparkle auto-update
  driven by an appcast hosted from the repository.
- Sparkle is embedded only in the packaged app; the domain kit never imports
  it, and update checks only start from a real installed bundle.
- **Signing material is never committed.** The Sparkle EdDSA private key lives
  in the Keychain; only the public key ships in the bundle. Developer ID
  identity and notary credentials come from local environment/Keychain, never
  the repository or logs.
- Releases are tagged `vX.Y.Z`; the appcast is regenerated from the built,
  signed artifact.

## Conventions

- Conventional Commits. **English everywhere** — code, comments, docs, copy,
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
to require breaking an established pattern** — introducing a second way to
format, a hardcoded dimension, a parallel persistence path, a new dependency, a
per-item timer, business logic in a view, or a new architectural layer —
**stop and confirm with the user before either forcing the change into the old
pattern or defining a new one.** Name the pattern in tension, the options, and
the tradeoff. Silent divergence is a defect. When a genuinely new pattern is
agreed, document it here in the same turn.

## Git and completion

- Follow the branch, commit, push, and versioning policies recorded in
  **Project identity and policy**.
- Check `git status --short --branch` before editing and before the final reply.
- Use focused Conventional Commits for durable changes. Commit only files that
  belong to the task; leave unrelated dirty files untouched and report them.
- Do not revert, overwrite, or discard user changes unless explicitly asked.
- Retain every current and future task artifact under `artifacts/` for user
  review. Never delete, move, truncate, destructively replace, or prune an
  artifact unless the user explicitly requests that exact cleanup; this
  includes temporary validation logs and failure evidence. Append new evidence,
  and update indexes/status files without erasing their prior findings.
- Every task or SDD cycle must keep a `REMAINING.md` in its artifact directory
  listing every skipped, incomplete, externally blocked, manually-only, or
  otherwise unvalidated item and every remaining risk/follow-up. Write an
  explicit `None` when nothing remains.
- Before finishing, close anything opened during the task (build processes,
  simulators, editors) so nothing runs unnecessarily.
- Final report includes: changed files, validation performed, artifacts
  kept/deleted, commit and push status, final `git status --short --branch`,
  unrelated dirty files, and remaining risks.

## Personal skill paths

- Domain glossary: `CONTEXT.md` (optional; create only when useful)
- ADRs: `docs/adr/` (only for hard-to-reverse, non-obvious decisions)
- Research notes: `docs/research/` (create only when persisting research)
- Handoffs: `.scratch/handoffs/`
- Prototypes: `.scratch/prototypes/`

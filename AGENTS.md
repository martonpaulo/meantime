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

- Display name: `Meantime`
- Code name: `Meantime`
- Slug: `meantime`
- Identifier name: `meantime`
- Icon: `site/apple-touch-icon.png`
- Description: world clocks in your macOS menu bar — scheduled clocks, quick
  calendar, time travel. Native, fast, private.
- Repository: `martonpaulo/meantime` (public)
- Public identifiers: bundle `com.perso.meantime`; SwiftPM package `Meantime`,
  library target `MeantimeKit`, executable target `Meantime`
- Landing page: `https://meantime.martonpaulo.com/`, built from `site/`
  in this repository and published by GitHub Pages; `docs/` holds developer
  documentation only and is never published
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
- Browser acceptance: Chromium and WebKit/Safari for the landing page and Format
  Builder. Gecko is outside the selected acceptance set.
- Commit subject: a commit made for an issue ends with `(#<issue number>)`.
- Merge policy: merge commit only for bot PRs, `gh pr merge <number> --merge --delete-branch`, so every branch commit reaches `main` ([martonpaulo/skill-deck#277](https://github.com/martonpaulo/skill-deck/issues/277)); squash and rebase are disabled.
  This does not authorize branches for ordinary project work.
- Required approving review: disabled. Main-only direct delivery has no PR review gate.
- Secret protection: GitHub secret scanning and push protection enabled.
- GitHub topics: `clock`, `macos`, `menu-bar`, `productivity`, `sparkle`, `swift`,
  `swiftui`, `time-travel`, `timezone`, `world-clock`.
- Skills baseline revision: `7cfc324fcded57145c36cc678977c070ed800692`
- Skills baseline applied: `2026-09-09`
- Delete branches after merge: enabled (bot PRs are the only branches)
- Release, signing, and secret storage: see **Distribution & signing** below

## Product

The product definition lives in [`docs/product.md`](docs/product.md): what
Meantime is, what success means, and what it deliberately excludes. Read it
before any product-facing change.

## Instruction hierarchy and sources of truth

- Follow the direct task, the most specific scoped guidance, this file, then
  general working agreements. Read relevant guidance before changing files.
- Code establishes current behavior, this file governs process, and accepted
  issue requirements govern desired behavior. Surface contradictions explicitly.
- Keep one canonical owner per rule. Documentation summarizes or links to it.
- Auditing and planning do not authorize implementation. Do not broaden a task
  into adjacent cleanup, dependency changes, or a later workflow phase.
- Make consequential decisions visible with evidence, the proposed change and
  its tradeoff. Use the client's structured question facility when available;
  resolved decisions are not asked again.

## Long-running operations

Use bounded yields and observable progress for builds, browser work and delegated
work. Report useful progress at least once per minute when supported. Inspect
output and state before retrying or interrupting; elapsed time alone does not
prove a stall. Preserve failure evidence, diagnose it, then choose a narrower
retry. Never add a timer or background service just to monitor task progress.

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

For website behavior or layout changes, run `make check` for JavaScript logic and
repository invariants, then exercise the affected flow in both Chromium and
WebKit/Safari. The current CI runs domain/JavaScript checks, not browser layout
or assistive-technology checks. Use an available compatible browser runtime; do
not install a second browser manager. Record engine/version, viewport, tested
states and results. Native Safari clipboard permission behavior and VoiceOver
speech require a real integration or human verification when a browser harness
cannot establish them; never report those checks from DOM assertions alone.

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

## Route map

Before editing under a path, read the file its row names. A module with rules of its own keeps them in its own `AGENTS.md` of at most 150 lines, beside a `CLAUDE.md` symlink, and has a row here; this file stays at most 200 lines.

| Path | Read first |
| :--- | :--- |
| `Sources/`, `Tests/`, `site/` | `docs/patterns.md` |
| `scripts/`, `.github/workflows/`, `appcast.xml` | `docs/distribution.md` |

## Git and completion

- Follow the branch, commit, push, and versioning policies recorded in
  **Project identity and policy**.
- Check `git status --short --branch` before editing and before the final reply.
- Use focused Conventional Commits for durable changes. Commit only files that
  belong to the task; leave unrelated dirty files untouched and report them.
- Do not revert, overwrite, or discard user changes unless explicitly asked.
- Before any GitHub write, inspect the exact payload for secrets and sensitive
  data; do not print a suspected secret. Use structured arguments and preserve
  unrelated fields. Never force-push or rewrite history as routine cleanup.
- Direct delivery closes an issue only after all criteria pass, its resolving
  commit is pushed, and the remote default branch is verified to contain it.
  Read the issue's closed state and reason back; a reference in a commit subject
  alone does not close it. An accepted validation gap is not a met criterion.
- Verified reusable project learning belongs in its existing canonical owner.
  Required task documentation is included; unrelated learning is proposed with
  evidence and an exact draft before any separate edit.
- Retain every current and future task artifact under `artifacts/` for user
  review. Never delete, move, truncate, destructively replace, or prune an
  artifact unless the user explicitly requests that exact cleanup; this
  includes temporary validation logs and failure evidence. Append new evidence,
  and update indexes/status files without erasing their prior findings.
- Before finishing, close anything opened during the task (build processes,
  simulators, editors) so nothing runs unnecessarily.
- Final report includes: changed files, validation performed, artifacts
  kept/deleted, commit and push status, final `git status --short --branch`,
  unrelated dirty files, and remaining risks.
- Never write a leftover-work file such as `REMAINING.md`; report what is left in the final reply.

## Skills

No project-owned Agent Skills are currently installed in this repository. Do not
vendor personal skills here. A future project skill owns its project-specific
procedure; a general skill keeps the surrounding workflow. Unclaimed tasks use
normal skill triggering. Codex reads this root guidance; `CLAUDE.md` is a symlink
to the same owner. No Gemini or Antigravity guidance surface is selected.

## Agent skill paths

- Product definition: `docs/product.md`
- Domain glossary: `CONTEXT.md` (optional; create only when useful)
- ADRs: `docs/adr/` (only for hard-to-reverse, non-obvious decisions)
- Research notes: `docs/research/` (create only when persisting research)
- Handoffs: `.scratch/handoffs/`
- Prototypes: `.scratch/prototypes/`

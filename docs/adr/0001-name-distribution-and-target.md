# ADR 0001: Name, distribution, and deployment target

Status: accepted · 2026-07-22

## Context

Meantime is a menu-bar world-clock app in a crowded niche. Several obvious names
are already taken on the App Store (ZoneBar, Clocker, There, Time, Atlas,
Zonely, Chrona, Meridian), and App Store app names are globally unique.

## Decisions

1. **Name: Meantime.** Chosen for memorability and the Greenwich-Mean-Time /
   "in the meantime" double meaning. A different world-clock app already uses
   "MeanTime (Ad-Free)" on the App Store, so the App Store name is not
   available for our listing.
2. **Distribution: direct download only.** A notarized Developer ID DMG plus
   Sparkle auto-update via a repository-hosted appcast. **No App Store.** This
   sidesteps the name collision, avoids sandbox constraints, and keeps releases
   fully self-controlled.
3. **Deployment target: macOS 26 (Tahoe) minimum.** The user prefers the newest
   stable APIs and design language over reach. This removes availability guards
   and lets the UI adopt the current platform look directly.

## Consequences

- Sparkle is an accepted runtime dependency for updates, embedded only in the
  packaged app (never in the domain kit), with update checks gated to real
  installed bundles.
- The app is signed with the stable Developer ID Application identity and
  notarized so Gatekeeper trusts it; signing material stays out of the repo.
- Revisiting the App Store later would require a distinct, available listing
  name and an App Sandbox build without Sparkle.

## Tradeoffs

Direct download reaches fewer users than the App Store and puts trust/update
burden on notarization + Sparkle, but it keeps the project simple, unblocked by
the name collision, and free of review and sandbox friction.

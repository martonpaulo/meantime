<div align="center">

<img src="docs/assets/app-icon.png" width="128" alt="Meantime app icon">

# Meantime

**World clocks in your macOS menu bar.**

[![CI](https://github.com/martonpaulo/meantime/actions/workflows/ci.yml/badge.svg)](https://github.com/martonpaulo/meantime/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/martonpaulo/meantime)](https://github.com/martonpaulo/meantime/releases/latest)
[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue)](#install)
[![MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

<img src="docs/screenshots/menu-bar.png" alt="Two world clocks in the macOS menu bar" width="260">

<img src="docs/screenshots/panel.png" alt="The Meantime panel: clocks, month calendar, and time travel" width="400">

</div>

Your team is in New York. Your mom is in Recife. Your client is in Tokyo.
**Meantime keeps their clocks one glance away** — right in the menu bar.

## ⚡ Install

**[Download the latest DMG →](https://github.com/martonpaulo/meantime/releases/latest)**

Open it, drag Meantime onto Applications, launch. Done — it updates itself.

> Free · open source · notarized by Apple · macOS 26+

## ✨ What it does

| | |
|---|---|
| 🕐 **Clocks in the menu bar** | One item per clock, or every clock combined into a single item |
| 🎨 **Three styles per clock** | `09:47` · `🇺🇸 09:47` · a tiny analog face |
| 📅 **Quick calendar** | Click the menu bar → see the month. "The 15th is a… Tuesday." |
| 🔮 **Time travel** | Pick a day, type a time — every clock previews that moment |
| ⏰ **Scheduled clocks** | Show the NY clock only 8–12 and 13–17 *NY time*; it hides itself outside those hours |
| ✏️ **Your format, your pattern** | Write any Unicode pattern — or assemble one visually in the [interactive format builder](https://martonpaulo.github.io/meantime/format.html) |
| 🏷️ **Labels & emoji** | "Mom", "Tokyo Office" — any name, any emoji, or the country's flag |
| 🚀 **Open at login** | Set it once, forget it |

## 🔋 Fast and honest about energy

- The time comes **straight from the system clock** — never a private counter,
  never a delayed repaint. Updates land exactly on the minute (or hour) boundary.
- Meantime wakes **only as often as what you show changes**. Hour-only in the
  menu bar? It wakes ~once an hour. Nothing visible ticking? No timer at all.
- Sleep/wake, time-zone changes, clock changes → instant resync.

## 🔒 Simple by design

No accounts. No sync. No widgets. No telemetry. The only network request
Meantime ever makes is checking this repository for updates ([Sparkle](https://sparkle-project.org)).

## 🖼️ Settings

<div align="center">
<img src="docs/screenshots/settings-clocks.png" alt="Clocks settings" width="440">
<img src="docs/screenshots/settings-format.png" alt="Format builder settings" width="440">
</div>

## 🛠 Build from source

```bash
make run    # build and run the debug app
make check  # build (warning-free) + tests + validation
make dmg    # the full installer DMG
```

`make` with no target lists everything. Docs: [architecture](docs/architecture.md) ·
[UI patterns](docs/ui-patterns.md) · [feature defaults](docs/feature-defaults.md) ·
[agent policy](AGENTS.md).

## 📦 Releasing (maintainers)

One-time: `make keys` (Sparkle key → Keychain) and a `notarytool`
credentials profile. Per release:

```bash
DEVELOPER_ID_IDENTITY="Developer ID Application: …" make dmg
NOTARY_PROFILE=<profile> make notarize DMG=artifacts/Meantime-x.y.z.dmg
make sign-update ZIP=artifacts/Meantime-x.y.z.zip
make appcast VERSION=x.y.z BUILD=<n> ZIP=… SIG='…'
git tag vx.y.z && git push --tags
```

Then upload the DMG + zip to the GitHub release. `make screenshots` refreshes
every image on this page from the real running app.

## 📄 License

[MIT](LICENSE) © 2026 Marton Paulo · Sparkle attribution in
[ATTRIBUTIONS.md](ATTRIBUTIONS.md)

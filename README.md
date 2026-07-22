# Meantime

**World clocks in your macOS menu bar.**

Meantime keeps the time in the places you care about one glance away — pinned
right in the menu bar, or tucked into a tidy dropdown. Add any time zone, name
it, give it an emoji, and check what time it is for your team, your family, or
your next trip without leaving what you're doing.

Native, fast, and private. No accounts, no sync, no telemetry.

## Features

- **Menu-bar clocks** — pin any time zone directly in the menu bar. Show one
  clock or several; the rest live in a click-to-open panel.
- **Three display styles per clock** — time only (`09:47`), flag + time
  (`🇺🇸 09:47`), or a small analog face with no text.
- **Time travel** — a slider previews what every clock reads hours from now, so
  planning a call across zones takes a second.
- **Fully custom time format** — pick a preset with a live example, write any
  Unicode date pattern, or just follow your Mac's system format.
- **Custom labels and emoji** — call a clock "Mom" or "Tokyo Office"; pick any
  emoji, or let Meantime use the region's flag.
- **Adjustable text size and spacing** — make the menu bar comfortable to read.
- **Open at login** — always there when you need it.
- **Energy-aware and always correct** — the time comes straight from the system
  clock and updates align to the coarsest unit you actually show. A bar that
  shows only the hour wakes about once an hour, not every minute; a bar that
  shows nothing that changes runs no timer at all. It re-syncs instantly on
  sleep/wake, clock changes, and time-zone changes.

## Install

### Download

Download the latest notarized `Meantime-x.y.z.dmg` from the
[Releases](https://github.com/martonpaulo/meantime/releases) page, open it, and
drag **Meantime** onto **Applications**. Launch it and a clock appears in your
menu bar. Meantime keeps itself up to date automatically.

### Build from source

Requires macOS 26 or later and the Swift 6.2 toolchain.

```bash
make run    # build and run the debug app
make dmg    # build the installer DMG
make check  # build, test, and validate
```

Run `make` with no target to see everything available.

## Using Meantime

Click any menu-bar clock to open the panel: every clock, the time-travel
slider, and app actions live there. Open **Settings** from the panel's `…` menu
to add clocks, rename them, choose emoji, pick each clock's menu-bar style, and
set the time format.

### Time format

Meantime formats time with standard Unicode date patterns, so you can shape it
exactly how you like:

| Pattern         | Example        |
| --------------- | -------------- |
| `System`        | follows macOS  |
| `HH:mm`         | `09:47`        |
| `H:mm`          | `9:47`         |
| `h:mm a`        | `9:47 AM`      |
| `HH:mm:ss`      | `09:47:30`     |
| `HH`            | `09`           |
| `EEE HH:mm`     | `Thu 09:47`    |
| `d MMM, HH:mm`  | `23 Jul, 09:47`|

Wrap literal text in single quotes (`HH'h'mm` → `09h47`). "Reset to system
default" returns to whatever your Mac is set to.

## Updating

Release builds use [Sparkle](https://sparkle-project.org) to check an appcast
hosted in this repository and update in place. Update checks are the only
network requests Meantime ever makes.

## Releasing (maintainers)

One-time per machine:

```bash
make keys   # generates the Sparkle key in your Keychain, sets the public key
xcrun notarytool store-credentials <profile> \
  --apple-id <you@example.com> --team-id TBN79KU9ML --password <app-specific>
```

Then, per release, with a Developer ID identity available:

```bash
DEVELOPER_ID_IDENTITY="Developer ID Application: …" make dmg
NOTARY_PROFILE=<profile> make notarize DMG=artifacts/Meantime-x.y.z.dmg
make sign-update ZIP=artifacts/Meantime-x.y.z.zip        # prints SIG=…
make appcast VERSION=x.y.z BUILD=<n> ZIP=artifacts/Meantime-x.y.z.zip SIG='sparkle:edSignature="…" length="…"'
git tag vx.y.z && git push --tags
# then upload the .dmg and .zip to the GitHub Release for the tag
```

See [docs/architecture.md](docs/architecture.md) and
[docs/ui-patterns.md](docs/ui-patterns.md) for how the app is built, and
[AGENTS.md](AGENTS.md) for the working agreement.

## License

[MIT](LICENSE) © 2026 Marton Paulo. Meantime bundles Sparkle in release builds;
see [ATTRIBUTIONS.md](ATTRIBUTIONS.md).

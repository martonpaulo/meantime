#!/bin/bash
# Creates the Meantime installer DMG: drag-to-Applications layout with background
# artwork, fixed icon positions, a volume icon, and (locally) a matching icon on
# the .dmg file itself. Built with appdmg (pinned), which writes the Finder
# layout programmatically — works headless, no Finder scripting.
# Usage: scripts/make-dmg.sh [version]
# Optional output overrides: APP_OUTPUT, DMG_OUTPUT, and DMG_WORK_DIR.
set -euo pipefail
cd "$(dirname "$0")/.."

DEFAULT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Support/Info.plist)
VERSION="${1:-$DEFAULT_VERSION}"
APPDMG_VERSION=0.6.6
APP="${APP_OUTPUT:-build/Meantime.app}"
DMG="${DMG_OUTPUT:-artifacts/Meantime-$VERSION.dmg}"
DMG_WORK_DIR="${DMG_WORK_DIR:-artifacts/dmg-$VERSION}"

[ -d "$APP" ] || { echo "$APP missing; run scripts/package-app.sh first"; exit 1; }
[ ! -e "$DMG" ] || {
    echo "$DMG already exists; choose a new DMG_OUTPUT so the existing artifact is retained"
    exit 1
}
[ ! -e "$DMG_WORK_DIR" ] || {
    echo "$DMG_WORK_DIR already exists; choose a new DMG_WORK_DIR so existing evidence is retained"
    exit 1
}

mkdir -p "$(dirname "$DMG")" "$DMG_WORK_DIR"
REPOSITORY_ROOT="$(pwd)"
APP_PATH="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"
SPEC="$DMG_WORK_DIR/dmg-spec.json"

# Icon centers must stay in sync with the background artwork
# (scripts/render-dmg-background.swift): window 660x420, icons at y 250.
cat > "$SPEC" <<JSON
{
  "title": "Meantime $VERSION",
  "icon": "$REPOSITORY_ROOT/Support/AppInstallerIcon.icns",
  "background": "$REPOSITORY_ROOT/Support/MeantimeInstallerBackground.tiff",
  "icon-size": 120,
  "window": { "size": { "width": 660, "height": 420 } },
  "contents": [
    { "x": 185, "y": 250, "type": "file", "path": "$APP_PATH" },
    { "x": 475, "y": 250, "type": "link", "path": "/Applications" }
  ]
}
JSON
npx --yes "appdmg@$APPDMG_VERSION" "$SPEC" "$DMG"

# Give the .dmg file itself the Meantime icon (resource fork; survives local
# copies — download services strip xattrs, so the VOLUME icon is the one users
# see after mounting).
if xcrun --find Rez >/dev/null 2>&1 && command -v SetFile >/dev/null 2>&1; then
    cp Support/AppInstallerIcon.icns "$DMG_WORK_DIR/dmg-file-icon.icns"
    sips -i "$DMG_WORK_DIR/dmg-file-icon.icns" >/dev/null
    DeRez -only icns "$DMG_WORK_DIR/dmg-file-icon.icns" > "$DMG_WORK_DIR/dmg-icon.rsrc"
    Rez -append "$DMG_WORK_DIR/dmg-icon.rsrc" -o "$DMG"
    SetFile -a C "$DMG"
fi

if [ -n "${DEVELOPER_ID_IDENTITY:-}" ]; then
    codesign --force --timestamp --sign "$DEVELOPER_ID_IDENTITY" "$DMG"
    echo "signed with $DEVELOPER_ID_IDENTITY"
fi

hdiutil verify "$DMG" -quiet && echo "hdiutil verify: ok"
echo "created $DMG"

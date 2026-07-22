#!/bin/bash
# Creates the Meantime installer DMG: drag-to-Applications layout with background
# artwork, fixed icon positions, a volume icon, and (locally) a matching icon on
# the .dmg file itself. Built with appdmg (pinned), which writes the Finder
# layout programmatically — works headless, no Finder scripting.
# Usage: scripts/make-dmg.sh [version]   (expects build/Meantime.app to exist)
set -euo pipefail
cd "$(dirname "$0")/.."

DEFAULT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Support/Info.plist)
VERSION="${1:-$DEFAULT_VERSION}"
APPDMG_VERSION=0.6.6
DMG="artifacts/Meantime-$VERSION.dmg"

[ -d build/Meantime.app ] || { echo "build/Meantime.app missing; run scripts/package-app.sh first"; exit 1; }

mkdir -p artifacts
rm -f "$DMG"

# Icon centers must stay in sync with the background artwork
# (scripts/render-dmg-background.swift): window 660x420, icons at y 250.
cat > artifacts/dmg-spec.json <<JSON
{
  "title": "Meantime $VERSION",
  "icon": "../Support/AppInstallerIcon.icns",
  "background": "../Support/MeantimeInstallerBackground.tiff",
  "icon-size": 120,
  "window": { "size": { "width": 660, "height": 420 } },
  "contents": [
    { "x": 185, "y": 250, "type": "file", "path": "../build/Meantime.app" },
    { "x": 475, "y": 250, "type": "link", "path": "/Applications" }
  ]
}
JSON
npx --yes "appdmg@$APPDMG_VERSION" artifacts/dmg-spec.json "$DMG"
rm -f artifacts/dmg-spec.json

# Give the .dmg file itself the Meantime icon (resource fork; survives local
# copies — download services strip xattrs, so the VOLUME icon is the one users
# see after mounting).
if xcrun --find Rez >/dev/null 2>&1 && command -v SetFile >/dev/null 2>&1; then
    cp Support/AppInstallerIcon.icns artifacts/dmg-file-icon.icns
    sips -i artifacts/dmg-file-icon.icns >/dev/null
    DeRez -only icns artifacts/dmg-file-icon.icns > artifacts/dmg-icon.rsrc
    Rez -append artifacts/dmg-icon.rsrc -o "$DMG"
    SetFile -a C "$DMG"
    rm -f artifacts/dmg-file-icon.icns artifacts/dmg-icon.rsrc
fi

if [ -n "${DEVELOPER_ID_IDENTITY:-}" ]; then
    codesign --force --timestamp --sign "$DEVELOPER_ID_IDENTITY" "$DMG"
    echo "signed with $DEVELOPER_ID_IDENTITY"
fi

hdiutil verify "$DMG" -quiet && echo "hdiutil verify: ok"
echo "created $DMG"

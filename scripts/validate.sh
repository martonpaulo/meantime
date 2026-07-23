#!/bin/bash
# Repository invariants that must always hold. Fast, grep-based; the build and
# tests run separately.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
note() { echo "FAIL: $1"; fail=1; }

# CLAUDE.md is a symlink to AGENTS.md (one agent-guidance source of truth).
if [ ! -L CLAUDE.md ] || [ "$(readlink CLAUDE.md)" != "AGENTS.md" ]; then
    note "CLAUDE.md must be a symlink to AGENTS.md"
fi

# The bundle identifier is fixed.
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" Support/Info.plist)
[ "$BUNDLE_ID" = "com.perso.meantime" ] || note "bundle id must be com.perso.meantime (got $BUNDLE_ID)"

# The domain kit stays pure: no UI or Sparkle imports.
if grep -rqE "import (SwiftUI|AppKit|Sparkle)" Sources/MeantimeKit; then
    note "MeantimeKit must not import SwiftUI, AppKit, or Sparkle"
fi

# No signing material is ever committed.
if git ls-files 2>/dev/null | grep -qiE '\.(p12|pem)$|_priv$'; then
    note "signing material must not be committed"
fi

# The panel is a menu-style status-item surface, not an arrowed popover.
if ! grep -q 'view.material = \.menu' Sources/Meantime/MenuBar/PanelController.swift; then
    note "the menu-bar panel must use AppKit's menu material"
fi

# Website navigation stays identical across the landing page and builder.
expected_navigation="Features|Format Builder|Download|GitHub"
for page in docs/index.html docs/format.html; do
    navigation=$(sed -n '/<nav aria-label="Page sections">/,/<\/nav>/p' "$page" \
        | sed -E -n 's/.*>([^<]+)<\/a>.*/\1/p' | paste -sd '|' -)
    [ "$navigation" = "$expected_navigation" ] \
        || note "$page navigation order must be $expected_navigation"
    grep -q 'aria-current="page"' "$page" \
        || note "$page must identify the current page"
done

# The guided builder exposes every product-supported field and separator. The
# raw input remains available for the rest of UTS-35.
for token in yy yyyy M MM MMM MMMM d dd EEE EEEE a h hh H HH m mm s ss z zzzz XXX VV; do
    if ! grep -q "data-token=\"$token\"" docs/format.html; then
        note "format builder is missing $token"
    fi
done
if ! grep -q 'tr35-dates.html#Date_Format_Patterns' docs/format.html; then
    note "format builder must link to the official Unicode pattern documentation"
fi
for separator in '/' '-' '.' ' ' ':' ',' '·'; do
    if ! grep -Fq "data-token=\"$separator\"" docs/format.html; then
        note "format builder is missing separator '$separator'"
    fi
done
if ! grep -q 'id="add-literal"' docs/format.html; then
    note "format builder must support literal text"
fi
if grep -Eqi 'free[[:space:]-]+tool' docs/*.html; then
    note "website must not advertise itself as a free tool"
fi
if grep -Eq 'screenshots/settings-(clocks|format)\\.png' README.md docs/*.html; then
    note "public pages must not reference the obsolete Settings screenshots"
fi

# Never publish a known-dead updater enclosure.
if grep -q '<sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>' appcast.xml; then
    note "appcast must not include the permanently unavailable 1.0.0 asset"
fi

if [ "$fail" -eq 0 ]; then
    echo "validate: ok"
else
    echo "validate: FAILED"
    exit 1
fi

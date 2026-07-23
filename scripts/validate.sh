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
for page in docs/index.html docs/format.html; do
    for label in "Features" "Format Builder" "Download" "GitHub"; do
        if ! grep -q ">$label</a>" "$page"; then
            note "$page navigation is missing $label"
        fi
    done
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
if grep -qi 'free tool' docs/format.html; then
    note "format builder must not advertise itself as a free tool"
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

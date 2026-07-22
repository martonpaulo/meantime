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

if [ "$fail" -eq 0 ]; then
    echo "validate: ok"
else
    echo "validate: FAILED"
    exit 1
fi

#!/bin/bash
# Signs a release zip with the Sparkle EdDSA key (from the Keychain) and prints
# the appcast signature attributes to pass to scripts/make-appcast.sh.
# Usage: scripts/sign-update.sh <zip-path>
set -euo pipefail
cd "$(dirname "$0")/.."

ZIP="${1:?usage: scripts/sign-update.sh <zip-path>}"
SIGN=$(find .build/artifacts -name sign_update -type f 2>/dev/null | head -1)
[ -n "$SIGN" ] || { echo "sign_update not found; run 'swift build' first"; exit 1; }

"$SIGN" "$ZIP"

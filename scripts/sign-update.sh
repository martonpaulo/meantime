#!/bin/bash
# Signs a release zip with the Sparkle EdDSA key and prints the appcast
# signature attributes to pass to scripts/make-appcast.sh. The sign_update tool
# comes from the Sparkle version pinned in Package.resolved.
# Without options the key is read from the login Keychain; CI passes the key on
# standard input instead: echo "$KEY" | scripts/sign-update.sh <zip> --ed-key-file -
# Usage: scripts/sign-update.sh <zip-path> [sign_update options]
set -euo pipefail
cd "$(dirname "$0")/.."

ZIP="${1:?usage: scripts/sign-update.sh <zip-path> [sign_update options]}"
shift
SIGN=$(find .build/artifacts -path '*/bin/sign_update' -type f 2>/dev/null | head -1)
[ -n "$SIGN" ] || { echo "sign_update not found; run 'swift build' first"; exit 1; }

"$SIGN" "$@" "$ZIP"

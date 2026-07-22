#!/bin/bash
# Notarizes and staples a Developer ID-signed DMG (or app) so Gatekeeper trusts
# direct downloads. Requires a stored notarytool credential profile; create one
# once with:
#   xcrun notarytool store-credentials <profile> \
#     --apple-id <you@example.com> --team-id TBN79KU9ML --password <app-specific>
# Usage: NOTARY_PROFILE=<profile> scripts/notarize.sh <path-to-dmg>
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:?usage: NOTARY_PROFILE=<profile> scripts/notarize.sh <path-to-dmg>}"
PROFILE="${NOTARY_PROFILE:?set NOTARY_PROFILE to your notarytool keychain profile}"

xcrun notarytool submit "$TARGET" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$TARGET"
xcrun stapler validate "$TARGET"
echo "notarized and stapled $TARGET"

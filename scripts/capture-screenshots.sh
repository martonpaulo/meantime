#!/bin/bash
# Renders deterministic 2x documentation screenshots from production views.
# The debug app stays offscreen, installs no status item, and never takes focus.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="docs/screenshots"
TEMP_OUTPUT=$(mktemp -d "${TMPDIR:-/tmp}/meantime-screenshots.XXXXXX")
cleanup() { rm -rf "$TEMP_OUTPUT"; }
trap cleanup EXIT

swift build
BIN=$(swift build --show-bin-path)/Meantime
"$BIN" --capture-screenshots "$TEMP_OUTPUT"

for name in menu-bar panel settings-clocks settings-format settings-general; do
    image="$TEMP_OUTPUT/$name.png"
    [ -f "$image" ] || { echo "missing rendered screenshot: $image"; exit 1; }
    width=$(sips -g pixelWidth "$image" 2>/dev/null | awk '/pixelWidth/ {print $2}')
    [ "${width:-0}" -ge 400 ] || { echo "$image is not Retina quality"; exit 1; }
done

mkdir -p "$OUT"
for name in menu-bar panel settings-clocks settings-format settings-general; do
    cp "$TEMP_OUTPUT/$name.png" "$OUT/$name.png"
done
cp "$OUT/panel.png" "$OUT/panel-current.png"
cp "$OUT/settings-clocks.png" "$OUT/settings-current.png"

echo "Updated offscreen 2x screenshots:"
sips -g pixelWidth -g pixelHeight "$OUT"/*.png

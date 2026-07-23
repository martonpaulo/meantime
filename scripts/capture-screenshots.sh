#!/bin/bash
# Captures the README/website screenshots from the real running app.
# Requires: build/Meantime.app built (scripts/package-app.sh), plus Screen
# Recording and Accessibility permissions for the invoking terminal.
# Usage: scripts/capture-screenshots.sh
# Output: docs/screenshots/*.png (2x Retina crops)
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=docs/screenshots
APP_PATH="${APP_PATH:-build/Meantime.app}"
PROCESS_NAME="${PROCESS_NAME:-Meantime}"
STAMP=$(date -u "+%Y%m%dT%H%M%SZ")
HISTORY="artifacts/screenshot-history/$STAMP"
mkdir -p "$OUT"

[ -d "$APP_PATH" ] || { echo "$APP_PATH missing; run scripts/package-app.sh first"; exit 1; }
[ ! -e "$HISTORY" ] || { echo "$HISTORY already exists; retry with a new timestamp"; exit 1; }
mkdir -p "$HISTORY"
find "$OUT" -maxdepth 1 -name '*.png' -exec cp {} "$HISTORY/" \;

open "$APP_PATH"
sleep 2

# Region of a UI element, as "x,y,w,h" in points (screencapture -R format).
panel_rect() {
    osascript <<EOF
tell application "System Events" to tell process "$PROCESS_NAME"
    click menu bar item 1 of menu bar 2
    delay 0.6
    set p to position of window 1
    set s to size of window 1
    return ((item 1 of p) as text) & "," & ((item 2 of p) as text) & "," & ¬
        ((item 1 of s) as text) & "," & ((item 2 of s) as text)
end tell
EOF
}

menubar_rect() {
    # AX item order is not left-to-right; take the min/max across all items.
    osascript <<EOF
tell application "System Events" to tell process "$PROCESS_NAME"
    set leftEdge to 100000
    set rightEdge to 0
    repeat with menuItem in menu bar items of menu bar 2
        set p to position of menuItem
        set s to size of menuItem
        if (item 1 of p) < leftEdge then set leftEdge to (item 1 of p)
        if ((item 1 of p) + (item 1 of s)) > rightEdge then ¬
            set rightEdge to ((item 1 of p) + (item 1 of s))
    end repeat
    return ((leftEdge - 12) as text) & ",0," & ((rightEdge - leftEdge + 24) as text) & ",26"
end tell
EOF
}

settings_rect() {
    osascript <<EOF
tell application "System Events" to tell process "$PROCESS_NAME"
    set frontmost to true
    delay 0.2
    click menu item "Settings…" of menu 1 of menu bar item 2 of menu bar 1
    delay 0.8
    click button "$1" of toolbar 1 of window 1
    delay 0.6
    set p to position of window 1
    set s to size of window 1
    return ((item 1 of p) as text) & "," & ((item 2 of p) as text) & "," & ¬
        ((item 1 of s) as text) & "," & ((item 2 of s) as text)
end tell
EOF
}

echo "capturing menu bar strip…"
screencapture -x -R "$(menubar_rect)" "$OUT/menu-bar.png"

echo "capturing panel…"
RECT=$(panel_rect)
screencapture -x -R "$RECT" "$OUT/panel.png"
osascript -e 'tell application "System Events" to key code 53' # ESC closes the panel

for pane in Clocks Format General; do
    echo "capturing $pane pane…"
    screencapture -x -R "$(settings_rect "$pane")" "$OUT/settings-$(echo "$pane" | tr '[:upper:]' '[:lower:]').png"
done
osascript -e "tell application \"System Events\" to tell process \"$PROCESS_NAME\" to keystroke \"w\" using command down"

cp "$OUT/panel.png" "$OUT/panel-current.png"
cp "$OUT/settings-clocks.png" "$OUT/settings-current.png"

echo "wrote $OUT:"
ls -la "$OUT"/*.png
echo "preserved previous screenshots in $HISTORY"

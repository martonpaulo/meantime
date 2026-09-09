#!/bin/bash
# Documentation screenshots, captured from the real windows on a real screen.
#
# Why on-screen and not offscreen: a window's shadow, corner radius, material
# and elevation are drawn by the window server, not by the view. An offscreen
# bitmap of the same view has none of them, and rendering at a larger scale does
# not bring them back. So the app opens its own window, prints that window's id,
# and `screencapture -l<id>` copies exactly what macOS drew.
#
# Rules this script keeps:
#   * Only Meantime's own windows are captured. Window ids come from the app
#     itself, never from guessing at the window list.
#   * `-o` is never passed: that is the flag that strips the shadow.
#   * A Retina display is required. A 1x display silently halves the capture.
#   * The window must be key at the moment of capture, or the traffic lights
#     come out grey and every control renders inactive. The app is an accessory
#     app and cannot take key focus on its own, so the capture runs from a
#     throwaway .app wrapper launched through LaunchServices, and announces
#     READY only once the window is genuinely key.
#   * Sizes come from the design tokens and a fixed clock fixture, so the
#     result does not depend on this machine's window sizes or display.
#   * Output is lossless WebP: identical pixels, the shadow's alpha preserved,
#     and roughly 70% fewer bytes than PNG.
#
# The menu-bar strip is the one exception. It has no window chrome to preserve
# and lives in the system menu bar, which is not Meantime's window, so it stays
# a deterministic offscreen render.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="docs/screenshots"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/meantime-screenshots.XXXXXX")
BUNDLE="$WORK/Meantime Capture.app"
cleanup() {
    pkill -f "Meantime Capture" 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

command -v cwebp >/dev/null || {
    echo "cwebp is required (brew install webp)"; exit 1
}

swift build
BIN_DIR=$(swift build --show-bin-path)

# A throwaway bundle: LaunchServices is what lets the app become frontmost, and
# a bare binary launched from a shell cannot. It is deleted on exit.
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Frameworks"
cp "$BIN_DIR/Meantime" "$BUNDLE/Contents/MacOS/Meantime Capture"
cp -R "$BIN_DIR/Sparkle.framework" "$BUNDLE/Contents/Frameworks/"
cat > "$BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Meantime Capture</string>
<key>CFBundleIdentifier</key><string>com.perso.meantime.capture</string>
<key>CFBundleName</key><string>Meantime Capture</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST

capture() {
    local subject="$1"
    local log="$WORK/$subject.log"
    : > "$log"
    open -n "$BUNDLE" --stdout "$log" --stderr "$WORK/$subject.err" \
        --args --capture-window "$subject"

    # Wait for the window to be open, key, and settled.
    local waited=0
    until grep -q '^READY$' "$log" 2>/dev/null; do
        sleep 0.2
        waited=$((waited + 1))
        [ "$waited" -lt 100 ] || { echo "timed out waiting for $subject"; cat "$WORK/$subject.err"; exit 1; }
    done

    local scale window_id key
    scale=$(awk '/^SCALE /{print $2}' "$log")
    window_id=$(awk '/^WINDOW_ID /{print $2}' "$log")
    key=$(awk '/^KEY /{print $2}' "$log")
    [ "$scale" = "2.0" ] || {
        echo "$subject: needs a Retina display, this one reports scale $scale"; exit 1
    }
    [ "$key" = "true" ] || {
        echo "$subject: the window was not key, controls would render inactive"; exit 1
    }

    # No -o: that flag is what removes the shadow.
    screencapture -l"$window_id" -x "$WORK/$subject.png"
    pkill -f "Meantime Capture" 2>/dev/null || true
    sleep 0.3
}

for subject in panel settings-clocks settings-format settings-general; do
    capture "$subject"
done

# The menu-bar strip has no window chrome, so it stays a deterministic render.
"$BIN_DIR/Meantime" --capture-screenshots "$WORK/rendered" >/dev/null
cp "$WORK/rendered/menu-bar.png" "$WORK/menu-bar.png"

mkdir -p "$OUT"
rm -f "$OUT"/*.png
for subject in menu-bar panel settings-clocks settings-format settings-general; do
    # -exact keeps the RGB values under fully transparent pixels, so the
    # shadow's soft edge is preserved rather than replaced with black.
    cwebp -quiet -lossless -exact "$WORK/$subject.png" -o "$OUT/$subject.webp"
done

echo "Captured screenshots (published width, and the width attribute to use):"
for image in "$OUT"/*.webp; do
    width=$(sips -g pixelWidth "$image" 2>/dev/null | awk '/pixelWidth/ {print $2}')
    height=$(sips -g pixelHeight "$image" 2>/dev/null | awk '/pixelHeight/ {print $2}')
    bytes=$(stat -f%z "$image")
    printf '  %-34s %5s x %-5s  %6s KB   width="%s"\n' \
        "$(basename "$image")" "$width" "$height" "$((bytes / 1024))" "$((width / 2))"
done

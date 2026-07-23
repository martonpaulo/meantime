#!/bin/bash
# Builds the Release binary and assembles a runnable Meantime.app with the
# Sparkle framework embedded, then zips it (Sparkle-safe).
#
# Signing:
#   - With DEVELOPER_ID_IDENTITY set: Developer ID + hardened runtime (release).
#   - Otherwise: ad-hoc signing — free to build and run locally.
#
# Usage: scripts/package-app.sh [version] [build-number]
# Optional output overrides: APP_OUTPUT and ZIP_OUTPUT.
# Defaults: build/Meantime.app and artifacts/Meantime-<version>.zip.
set -euo pipefail
cd "$(dirname "$0")/.."

DEFAULT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Support/Info.plist)
DEFAULT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Support/Info.plist)
VERSION="${1:-$DEFAULT_VERSION}"
BUILD_NUMBER="${2:-$DEFAULT_BUILD}"
IDENTITY="${DEVELOPER_ID_IDENTITY:--}"

[ -f Support/AppIcon.icns ] || { echo "Support/AppIcon.icns missing; run scripts/make-icon.swift"; exit 1; }

swift build -c release

APP="${APP_OUTPUT:-build/Meantime.app}"
ZIP="${ZIP_OUTPUT:-artifacts/Meantime-$VERSION.zip}"

[ ! -e "$APP" ] || {
    echo "$APP already exists; choose a new APP_OUTPUT so the existing artifact is retained"
    exit 1
}
[ ! -e "$ZIP" ] || {
    echo "$ZIP already exists; choose a new ZIP_OUTPUT so the existing artifact is retained"
    exit 1
}

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp .build/release/Meantime "$APP/Contents/MacOS/Meantime"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
if [ -d Support/en.lproj ]; then
    ditto Support/en.lproj "$APP/Contents/Resources/en.lproj"
fi
# ditto preserves the framework's symlink structure; cp -R would break it.
ditto .build/release/Sparkle.framework "$APP/Contents/Frameworks/Sparkle.framework"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"

# Sign nested code first (Sparkle's helpers), then the framework, then the app.
SIGN_FLAGS=(--force --sign "$IDENTITY")
if [ "$IDENTITY" != "-" ]; then
    SIGN_FLAGS+=(--timestamp --options runtime)
fi
codesign "${SIGN_FLAGS[@]}" "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc"
codesign "${SIGN_FLAGS[@]}" "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"
codesign "${SIGN_FLAGS[@]}" "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
codesign "${SIGN_FLAGS[@]}" "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
codesign "${SIGN_FLAGS[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
codesign "${SIGN_FLAGS[@]}" "$APP"
codesign --verify --deep --strict "$APP"

mkdir -p "$(dirname "$ZIP")"
# ditto -c -k preserves symlinks and signatures, as Sparkle requires.
ditto -c -k --keepParent "$APP" "$ZIP"

echo "built $APP (version $VERSION, build $BUILD_NUMBER, identity: $IDENTITY)"
echo "zipped $ZIP"

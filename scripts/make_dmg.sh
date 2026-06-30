#!/usr/bin/env bash
# ============================================================
# Packages DevDisk Cleaner into a .dmg (macOS, outside the App Store),
# signed with a Developer ID and notarized by Apple.
#
# Usage:
#   ./scripts/make_dmg.sh            # build + sign + DMG + notarize + staple
#   ./scripts/make_dmg.sh --no-sign  # build + DMG only (no signing/notarization)
#
# Signing config comes from the environment (so no personal identity is
# committed):
#   DEVDISK_SIGN_IDENTITY  e.g. "Developer ID Application: Your Name (TEAMID)"
#   DEVDISK_NOTARY_PROFILE notarytool keychain profile name (default: devdisk-notary)
#
# Requires: flutter, create-dmg (brew install create-dmg), and — for signing —
# a "Developer ID Application" cert in the keychain plus a stored notarytool
# profile (xcrun notarytool store-credentials ...).
# Output: dist/DevDisk Cleaner.dmg
# ============================================================
set -euo pipefail

APP_NAME="DevDisk Cleaner"
APP_BUNDLE="$APP_NAME.app"
RELEASE_DIR="build/macos/Build/Products/Release"
DIST_DIR="dist"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

SIGN_IDENTITY="${DEVDISK_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${DEVDISK_NOTARY_PROFILE:-devdisk-notary}"
ENTITLEMENTS="macos/Runner/Release.entitlements"

DO_SIGN=true
[ "${1:-}" = "--no-sign" ] && DO_SIGN=false

cd "$(dirname "$0")/.."

if $DO_SIGN && [ -z "$SIGN_IDENTITY" ]; then
  echo "❌ Signing requested but DEVDISK_SIGN_IDENTITY is not set."
  echo "   export DEVDISK_SIGN_IDENTITY=\"Developer ID Application: Your Name (TEAMID)\""
  echo "   (and store a notarytool profile named '\$DEVDISK_NOTARY_PROFILE')."
  echo "   Or run with --no-sign for an unsigned local DMG."
  exit 1
fi

echo "▶ flutter build macos --release"
flutter build macos --release
[ -d "$RELEASE_DIR/$APP_BUNDLE" ] || { echo "❌ missing $APP_BUNDLE"; exit 1; }

if $DO_SIGN; then
  echo "▶ codesign the .app (Developer ID + hardened runtime)"
  codesign --deep --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$SIGN_IDENTITY" \
    "$RELEASE_DIR/$APP_BUNDLE"
  codesign --verify --deep --strict --verbose=2 "$RELEASE_DIR/$APP_BUNDLE"
fi

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

echo "▶ create-dmg"
# create-dmg can exit non-zero even when it produced the DMG (an AppleScript
# styling quirk), so we check the file afterwards instead of the exit code.
set +e
create-dmg \
  --volname "$APP_NAME" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 120 \
  --icon "$APP_BUNDLE" 165 175 \
  --hide-extension "$APP_BUNDLE" \
  --app-drop-link 495 175 \
  "$DMG_PATH" \
  "$RELEASE_DIR/$APP_BUNDLE"
set -e
[ -f "$DMG_PATH" ] || { echo "❌ failed to create the DMG"; exit 1; }
echo "✓ DMG: $DMG_PATH"

if $DO_SIGN; then
  echo "▶ codesign the .dmg (so the disk image itself carries a Developer ID signature)"
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
  echo "▶ notarytool submit (waits for Apple's result)…"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "▶ stapler staple"
  xcrun stapler staple "$DMG_PATH"
  echo "▶ Gatekeeper check (informational)"
  spctl -a -t open --context context:primary-signature -v "$DMG_PATH" \
    || echo "  (note: spctl could not assess by signature — the staple was already validated)"
  echo "✓ Signed and notarized DMG: $DMG_PATH"
fi

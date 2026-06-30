#!/usr/bin/env bash
# ============================================================
# Empacota o DevDisk Cleaner num .dmg (macOS, fora da App Store),
# assinado com Developer ID e notarizado pela Apple.
#
# Uso:
#   ./scripts/make_dmg.sh            # build + assina + DMG + notariza + staple
#   ./scripts/make_dmg.sh --no-sign  # só build + DMG (sem assinar/notarizar)
#
# Requer: flutter, create-dmg, e (p/ assinar) o cert "Developer ID
# Application" na Keychain + perfil do notarytool ($NOTARY_PROFILE).
# Saída:  dist/DevDisk Cleaner.dmg
# ============================================================
set -euo pipefail

APP_NAME="DevDisk Cleaner"
APP_BUNDLE="$APP_NAME.app"
RELEASE_DIR="build/macos/Build/Products/Release"
DIST_DIR="dist"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

SIGN_IDENTITY="Developer ID Application: Dener Oliveira (6DCF2LC242)"
NOTARY_PROFILE="devdisk-notary"
ENTITLEMENTS="macos/Runner/Release.entitlements"

DO_SIGN=true
[ "${1:-}" = "--no-sign" ] && DO_SIGN=false

cd "$(dirname "$0")/.."

echo "▶ flutter build macos --release"
flutter build macos --release
[ -d "$RELEASE_DIR/$APP_BUNDLE" ] || { echo "❌ não achei $APP_BUNDLE"; exit 1; }

if $DO_SIGN; then
  echo "▶ codesign (Developer ID + hardened runtime)"
  codesign --deep --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$SIGN_IDENTITY" \
    "$RELEASE_DIR/$APP_BUNDLE"
  codesign --verify --deep --strict --verbose=2 "$RELEASE_DIR/$APP_BUNDLE"
fi

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

echo "▶ create-dmg"
# create-dmg pode sair !=0 mesmo gerando o DMG (quirk do AppleScript); checamos
# o arquivo no fim em vez de confiar no exit code.
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
[ -f "$DMG_PATH" ] || { echo "❌ falha ao gerar o DMG"; exit 1; }
echo "✓ DMG: $DMG_PATH"

if $DO_SIGN; then
  echo "▶ codesign do DMG (p/ o próprio .dmg ter assinatura Developer ID)"
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
  echo "▶ notarytool submit (aguarda o resultado da Apple)…"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "▶ stapler staple"
  xcrun stapler staple "$DMG_PATH"
  echo "▶ validação Gatekeeper (informativa)"
  spctl -a -t open --context context:primary-signature -v "$DMG_PATH" \
    || echo "  (aviso: spctl não avaliou via assinatura — o staple já foi validado)"
  echo "✓ DMG assinado e notarizado: $DMG_PATH"
fi

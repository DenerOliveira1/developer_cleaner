#!/usr/bin/env bash
# ============================================================
# Empacota o DevDisk Cleaner num .dmg (macOS, fora da App Store).
#
# Uso:
#   ./scripts/make_dmg.sh
#
# Requer: flutter, create-dmg (brew install create-dmg).
# Saída:  dist/DevDisk Cleaner.dmg
# ============================================================
set -euo pipefail

APP_NAME="DevDisk Cleaner"
APP_BUNDLE="$APP_NAME.app"
RELEASE_DIR="build/macos/Build/Products/Release"
DIST_DIR="dist"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

cd "$(dirname "$0")/.."

echo "▶ flutter build macos --release"
flutter build macos --release

if [ ! -d "$RELEASE_DIR/$APP_BUNDLE" ]; then
  echo "❌ Não encontrei $RELEASE_DIR/$APP_BUNDLE"
  exit 1
fi

# --- (opcional) Assinatura com Developer ID — antes de notarizar ---
# Requer o certificado "Developer ID Application" (Apple Developer Program pago).
# codesign --deep --force --options runtime \
#   --sign "Developer ID Application: SEU NOME (TEAMID)" \
#   "$RELEASE_DIR/$APP_BUNDLE"

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

echo "▶ create-dmg"
# create-dmg pode retornar !=0 mesmo gerando o DMG (quirk ao estilizar via
# AppleScript). Por isso não usamos 'set -e' aqui e checamos o arquivo no fim.
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

if [ ! -f "$DMG_PATH" ]; then
  echo "❌ Falha ao gerar o DMG."
  exit 1
fi
echo "✓ DMG: $DMG_PATH"

# --- (opcional) Notarização — requer Developer ID + perfil do notarytool ---
# Configurar UMA vez (guarda credenciais no Keychain):
#   xcrun notarytool store-credentials devdisk-notary \
#     --apple-id "SEU_APPLE_ID" --team-id "TEAMID" \
#     --password "SENHA_ESPECIFICA_DE_APP"
# Depois, a cada release:
#   xcrun notarytool submit "$DMG_PATH" --keychain-profile devdisk-notary --wait
#   xcrun stapler staple "$DMG_PATH"
#   spctl -a -t open --context context:primary-signature -v "$DMG_PATH"  # valida

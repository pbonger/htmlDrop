#!/bin/bash
set -euo pipefail

# Run from project root
cd "$(dirname "$0")/.."

VERSION=$(node -p "require('./package.json').version")
PKG_ROOT=$(mktemp -d)
STAGING=$(mktemp -d)
DMG_TMP="/tmp/HTMLDrop-rw-$$.dmg"
PKG_PATH="build/HTMLDrop-v${VERSION}.pkg"
DMG_FINAL="build/HTMLDrop-v${VERSION}.dmg"
VOL_NAME="HTML Drop v${VERSION}"
PLUGIN_ZIP="build/distributions/html-drop-plugin-${VERSION}.zip"

cleanup() {
  rm -rf "$PKG_ROOT"
  rm -rf "$STAGING"
  rm -f "$DMG_TMP"
}
trap cleanup EXIT

echo "→ Checking prerequisites..."
if [ ! -f "$PLUGIN_ZIP" ]; then
  echo "Error: WebStorm plugin not found at $PLUGIN_ZIP"
  echo "Run 'npm run build' first."
  exit 1
fi
if [ ! -d "finder/HTMLDrop.app" ]; then
  echo "Error: finder/HTMLDrop.app not found."
  echo "Run 'npm run build:app' first."
  exit 1
fi

# ── Build .pkg ────────────────────────────────────────────────────────────────
echo "→ Building pkg payload..."

mkdir -p "$PKG_ROOT/Applications"
cp -r "finder/HTMLDrop.app" "$PKG_ROOT/Applications/"

mkdir -p "$PKG_ROOT/tmp/html-drop-install"
cp "$PLUGIN_ZIP" "$PKG_ROOT/tmp/html-drop-install/html-drop-plugin.zip"

echo "→ Running pkgbuild..."
mkdir -p build

COMPONENT_PLIST="/tmp/html-drop-component-$$.plist"
pkgbuild --analyze --root "$PKG_ROOT" "$COMPONENT_PLIST"
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$COMPONENT_PLIST"

pkgbuild \
  --root "$PKG_ROOT" \
  --identifier com.pbonger.html-drop \
  --version "$VERSION" \
  --scripts finder/pkg-scripts \
  --install-location / \
  --component-plist "$COMPONENT_PLIST" \
  "$PKG_PATH"

rm -f "$COMPONENT_PLIST"
rm -rf "$PKG_ROOT"

# ── Generate DMG background image ────────────────────────────────────────────
echo "→ Generating background image..."
BG_DIR="$STAGING/.background"
mkdir -p "$BG_DIR"
swift scripts/generate-dmg-bg.swift "$BG_DIR/bg.png"

# ── Stage DMG contents ────────────────────────────────────────────────────────
echo "→ Staging DMG contents..."
cp "$PKG_PATH" "$STAGING/HTML Drop.pkg"

echo "→ Creating writable disk image..."
hdiutil create \
  -srcfolder "$STAGING" \
  -volname "$VOL_NAME" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,b=16" \
  -format UDRW \
  -size 30m \
  "$DMG_TMP"

rm -rf "$STAGING"

echo "→ Mounting..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TMP" | grep '^/dev/' | head -1 | awk '{print $1}')
sleep 3

echo "→ Applying window layout..."
osascript <<EOF
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {300, 160, 860, 460}
    set theViewOptions to icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 80
    set background picture of theViewOptions to file ".background:bg.png"
    set position of item "HTML Drop.pkg" of container window to {415, 148}
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
EOF

echo "→ Unmounting..."
hdiutil detach "$DEVICE"
sleep 2

echo "→ Converting to compressed read-only DMG..."
hdiutil convert "$DMG_TMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL"

echo ""
echo "✓ Created: $DMG_FINAL"

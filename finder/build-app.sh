#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SDK="$(xcrun --show-sdk-path)"
SWIFTC="$(xcrun -f swiftc)"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macos12.0"

APP_NAME="HTMLDrop"
EXT_NAME="HTMLDropExtension"
BUNDLE_ID_APP="com.pbonger.html-drop-app"
BUNDLE_ID_EXT="com.pbonger.html-drop-app.extension"

TMP="$DIR/.build-app"
APP="$DIR/${APP_NAME}.app"
APPEX="$APP/Contents/PlugIns/${EXT_NAME}.appex"

rm -rf "$TMP" "$APP"
mkdir -p "$TMP"

# ── Extension ────────────────────────────────────────────────────────────────
echo "▸ Compiling extension…"
"$SWIFTC" \
  -sdk "$SDK" -target "$TARGET" \
  -module-name "$EXT_NAME" \
  "$DIR/Sources/HTMLDropCore.swift" \
  "$DIR/Extension/main.swift" \
  "$DIR/Extension/ShareViewController.swift" \
  -framework Foundation -framework AppKit -framework Security -framework CryptoKit \
  -o "$TMP/$EXT_NAME"

echo "▸ Bundling .appex…"
mkdir -p "$APPEX/Contents/MacOS" "$APPEX/Contents/Resources"
cp "$TMP/$EXT_NAME" "$APPEX/Contents/MacOS/$EXT_NAME"

# Copy icon + terminal-notifier from workflow bundle if present
WORKFLOW_RES="$DIR/HTMLDrop.workflow/Contents/Resources"
[ -f "$WORKFLOW_RES/icon.icns" ]               && cp "$WORKFLOW_RES/icon.icns" "$APPEX/Contents/Resources/AppIcon.icns"
[ -d "$WORKFLOW_RES/terminal-notifier.app" ]   && cp -r "$WORKFLOW_RES/terminal-notifier.app" "$APPEX/Contents/Resources/"

cat > "$APPEX/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleDisplayName</key><string>HTMLDrop</string>
  <key>CFBundleExecutable</key><string>${EXT_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID_EXT}</string>
  <key>CFBundleName</key><string>HTMLDrop</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>XPC!</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>NSExtension</key><dict>
    <key>NSExtensionAttributes</key><dict>
      <key>NSExtensionActivationRule</key>
      <string>SUBQUERY(extensionItems,\$i,SUBQUERY(\$i.attachments,\$a,ANY \$a.registeredTypeIdentifiers UTI-CONFORMS-TO "public.html").@count==\$i.attachments.@count).@count>0</string>
      <key>NSExtensionServiceAllowsFinderPreviewItem</key><true/>
      <key>NSExtensionServiceRoleType</key><string>NSExtensionServiceRoleTypeEditor</string>
    </dict>
    <key>NSExtensionPointIdentifier</key><string>com.apple.share-services</string>
    <key>NSExtensionPrincipalClass</key><string>ShareViewController</string>
  </dict>
</dict></plist>
PLIST

# ── Host app ─────────────────────────────────────────────────────────────────
echo "▸ Compiling host app…"
"$SWIFTC" \
  -sdk "$SDK" -target "$TARGET" \
  -module-name "$APP_NAME" \
  "$DIR/App/main.swift" \
  -framework Foundation -framework AppKit \
  -o "$TMP/$APP_NAME"

echo "▸ Bundling .app…"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$TMP/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
[ -f "$WORKFLOW_RES/icon.icns" ] && cp "$WORKFLOW_RES/icon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID_APP}</string>
  <key>CFBundleName</key><string>HTMLDrop</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST

# ── Ad-hoc sign ───────────────────────────────────────────────────────────────
echo "▸ Signing…"
codesign --sign - --force --deep "$APPEX"
codesign --sign - --force --deep "$APP"

echo "✓ Built: $APP"

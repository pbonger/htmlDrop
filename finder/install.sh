#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY_DEST="/usr/local/bin/netlify-share"
WORKFLOW_DEST="$HOME/Library/Services/NetlifyShare.workflow"

echo "Building netlify-share CLI..."
cd "$SCRIPT_DIR"
swift build -c release 2>&1

echo "Installing binary to $BINARY_DEST..."
cp ".build/release/netlify-share" "$BINARY_DEST"
chmod +x "$BINARY_DEST"

echo "Installing Quick Action..."
rm -rf "$WORKFLOW_DEST"
cp -R "NetlifyShare.workflow" "$WORKFLOW_DEST"

echo "Refreshing services database..."
/System/Library/CoreServices/pbs -update
killall -HUP Finder 2>/dev/null || true

echo ""
echo "Done! Right-click any .html file in Finder → Quick Actions → Share on Netlify"
echo "If Quick Actions doesn't appear: right-click → Quick Actions → Customize..."
echo "and enable 'Share on Netlify'."

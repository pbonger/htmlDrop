#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY_DEST="/usr/local/bin/html-drop"
WORKFLOW_DEST="$HOME/Library/Services/HTMLDrop.workflow"

echo "Building html-drop CLI..."
cd "$SCRIPT_DIR"
swift build -c release 2>&1

echo "Installing binary to $BINARY_DEST..."
cp ".build/release/html-drop" "$BINARY_DEST"
chmod +x "$BINARY_DEST"

echo "Installing Quick Action..."
rm -rf "$WORKFLOW_DEST"
cp -R "HTMLDrop.workflow" "$WORKFLOW_DEST"

echo "Refreshing services database..."
/System/Library/CoreServices/pbs -update
killall -HUP Finder 2>/dev/null || true

echo ""
echo "Done! Right-click any .html file in Finder → Quick Actions → Share on HTML Drop"
echo "If Quick Actions doesn't appear: right-click → Quick Actions → Customize..."
echo "and enable 'Share on HTML Drop'."

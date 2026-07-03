#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_BUNDLE="$PROJECT_DIR/ClipBoard.app"
INSTALL_DIR="/Applications"

echo "📦 Building app..."
"$SCRIPT_DIR/build-app.sh"

echo "📋 Installing to $INSTALL_DIR..."
if [ -d "$INSTALL_DIR/ClipBoard.app" ]; then
    echo "⚠️ Removing old version..."
    rm -rf "$INSTALL_DIR/ClipBoard.app"
fi

cp -R "$APP_BUNDLE" "$INSTALL_DIR/"

echo "✅ ClipBoard installed to Applications!"
echo "   You can now launch it from Launchpad or Spotlight."

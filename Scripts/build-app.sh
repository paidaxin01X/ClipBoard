#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SWIFT_DIR="$PROJECT_DIR/ClipBoard"

APP_NAME="ClipBoard"
BUILD_DIR=".build/release"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "🔨 Building release binary..."
cd "$SWIFT_DIR"
swift build -c release --product ClipBoard

echo "📦 Creating $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "📄 Copying binary..."
cp "$SWIFT_DIR/$BUILD_DIR/ClipBoard" "$MACOS_DIR/"

echo "📄 Copying Info.plist..."
cp "$SWIFT_DIR/Sources/ClipBoard/Info.plist" "$CONTENTS/"

# 如果存在图标则复制
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/"
fi

echo "✅ Done! $APP_BUNDLE created successfully."

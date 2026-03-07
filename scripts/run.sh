#!/bin/bash
# Build and run SessionTimer on device or simulator
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Check if xcbeautify is installed
if command -v xcbeautify &> /dev/null; then
    BEAUTIFY="xcbeautify"
else
    BEAUTIFY="cat"
fi

# Check if project exists
if [ ! -d "SessionTimer.xcodeproj" ]; then
    echo "⚠️  Project not found. Generating..."
    ./scripts/generate.sh
fi

# Detect connected device via devicectl (provides correct CoreDevice identifier)
DEVICE_LINE=$(xcrun devicectl list devices 2>&1 | grep -E "iPhone|iPad" | grep "connected" | head -1)
DEVICE_NAME=$(echo "$DEVICE_LINE" | awk -F'   ' '{print $1}' | xargs)
DEVICE_ID=$(echo "$DEVICE_LINE" | awk -F'   ' '{for(i=1;i<=NF;i++){gsub(/^ +| +$/,"",$i); if($i ~ /^[0-9A-Fa-f-]{36}$/){print $i}}}')

if [ -z "$DEVICE_NAME" ] && [ -z "$1" ]; then
    echo "📱 No iOS device connected, using simulator..."
    SIMULATOR="${1:-iPhone 17 Pro}"
    DESTINATION="platform=iOS Simulator,name=$SIMULATOR"

    echo "🔨 Building for simulator: $SIMULATOR"
    xcodebuild -project SessionTimer.xcodeproj \
               -scheme SessionTimer \
               -destination "$DESTINATION" \
               -derivedDataPath build \
               build 2>&1 | $BEAUTIFY

    echo "🚀 Launching simulator..."
    xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
    xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/SessionTimer.app
    xcrun simctl launch booted me.melkor.SessionTimer

    echo "✅ App launched on simulator: $SIMULATOR"
else
    echo "📲 Found device: $DEVICE_NAME (ID: $DEVICE_ID)"

    echo "🔨 Building for device..."
    xcodebuild -project SessionTimer.xcodeproj \
               -scheme SessionTimer \
               -destination 'generic/platform=iOS' \
               -allowProvisioningUpdates \
               -derivedDataPath build \
               build 2>&1 | $BEAUTIFY

    APP_PATH="build/Build/Products/Debug-iphoneos/SessionTimer.app"

    if [ ! -d "$APP_PATH" ]; then
        echo "❌ App not found at $APP_PATH"
        exit 1
    fi

    if [ -z "$DEVICE_ID" ]; then
        echo "❌ Could not determine device identifier. Please install manually via Xcode."
        exit 1
    fi

    echo "📦 Installing app..."
    xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

    echo "🚀 Launching app..."
    xcrun devicectl device process launch --device "$DEVICE_ID" me.melkor.SessionTimer

    echo "✅ App launched on device: $DEVICE_NAME"
fi

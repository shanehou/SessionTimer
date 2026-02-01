#!/bin/bash
# Build and run SessionTimer on device or simulator
set -e

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

# Detect connected device
DEVICE=$(xcrun xctrace list devices 2>&1 | grep -E "iPhone|iPad" | grep -v "Simulator" | head -1 | sed 's/ (.*//')

if [ -z "$DEVICE" ] && [ -z "$1" ]; then
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
    if [ -n "$1" ]; then
        DEVICE="$1"
    fi
    
    echo "📲 Found device: $DEVICE"
    DESTINATION="platform=iOS,name=$DEVICE"
    
    echo "🔨 Building for device..."
    xcodebuild -project SessionTimer.xcodeproj \
               -scheme SessionTimer \
               -destination "$DESTINATION" \
               -derivedDataPath build \
               build 2>&1 | $BEAUTIFY
    
    echo "📦 Installing app..."
    # Get device UDID - format: "设备名 (版本) (UDID)"
    UDID=$(xcrun xctrace list devices 2>&1 | grep "$DEVICE" | grep -v "Simulator" | head -1 | sed -E 's/.*\(([0-9A-Fa-f-]{20,})\)$/\1/')
    
    if [ -n "$UDID" ]; then
        echo "📱 Device UDID: $UDID"
        APP_PATH="build/Build/Products/Debug-iphoneos/SessionTimer.app"
        
        if [ -d "$APP_PATH" ]; then
            xcrun devicectl device install app --device "$UDID" "$APP_PATH" && \
            echo "🚀 Launching app..." && \
            xcrun devicectl device process launch --device "$UDID" me.melkor.SessionTimer || \
            echo "⚠️  Install failed. Please install manually via Xcode."
        else
            echo "⚠️  App not found at $APP_PATH. Please build with -derivedDataPath build first."
        fi
    else
        echo "⚠️  Could not get device UDID. Please install manually via Xcode."
    fi
    
    echo "✅ Build completed for device: $DEVICE"
fi

#!/bin/bash
# Build SessionTimer project
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

echo "🔨 Building project..."
xcodebuild -project SessionTimer.xcodeproj \
           -scheme SessionTimer \
           -destination 'generic/platform=iOS' \
           build 2>&1 | $BEAUTIFY

echo "✅ Build completed"

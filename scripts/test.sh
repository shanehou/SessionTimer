#!/bin/bash
# Run SessionTimer tests
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

SIMULATOR="${1:-iPhone 17 Pro}"

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

echo "🧪 Running tests on $SIMULATOR..."
xcodebuild test \
           -project SessionTimer.xcodeproj \
           -scheme SessionTimer \
           -destination "platform=iOS Simulator,name=$SIMULATOR" \
           2>&1 | $BEAUTIFY

echo "✅ Tests completed"

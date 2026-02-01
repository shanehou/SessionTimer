#!/bin/bash
# Generate Xcode project using XcodeGen
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Check if xcodegen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "❌ XcodeGen is not installed. Install it with: brew install xcodegen"
    exit 1
fi

echo "🔧 Generating Xcode project..."
xcodegen generate

echo "✅ Project generated: SessionTimer.xcodeproj"

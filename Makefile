.PHONY: generate build run-simulator run-device test clean help setup-vendor

# Default simulator device
SIMULATOR ?= iPhone 17 Pro

generate:
	@echo "🔧 Generating Xcode project..."
	xcodegen generate

build:
	@echo "🔨 Building project..."
	xcodebuild -project SessionTimer.xcodeproj \
	           -scheme SessionTimer \
	           -destination 'generic/platform=iOS' \
	           -allowProvisioningUpdates \
	           build | xcbeautify

run-simulator:
	@echo "📱 Building and running on simulator..."
	xcodebuild -project SessionTimer.xcodeproj \
	           -scheme SessionTimer \
	           -destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
	           -derivedDataPath build \
	           build | xcbeautify
	@echo "🚀 Launching simulator..."
	xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true
	xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/SessionTimer.app
	xcrun simctl launch booted me.melkor.SessionTimer

run-device:
	@echo "📲 Building and running on device..."
	./scripts/run.sh

test:
	@echo "🧪 Running tests..."
	xcodebuild test \
	           -project SessionTimer.xcodeproj \
	           -scheme SessionTimer \
	           -destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
	           | xcbeautify

test-ui:
	@echo "🧪 Running UI tests..."
	xcodebuild test \
	           -project SessionTimer.xcodeproj \
	           -scheme SessionTimer \
	           -destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
	           -only-testing:SessionTimerUITests \
	           | xcbeautify

setup-vendor:
	@echo "📦 Setting up vendor dependencies..."
	./scripts/setup-vendor.sh

clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf build/
	rm -rf DerivedData/
	xcodebuild clean -project SessionTimer.xcodeproj -scheme SessionTimer 2>/dev/null || true

help:
	@echo "Available targets:"
	@echo "  generate       - Generate Xcode project from project.yml"
	@echo "  build          - Build the project"
	@echo "  run-simulator  - Build and run on simulator (default: $(SIMULATOR))"
	@echo "  run-device     - Build and run on connected device"
	@echo "  test           - Run unit tests"
	@echo "  test-ui        - Run UI tests"
	@echo "  clean          - Clean build artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  SIMULATOR      - Simulator device name (default: iPhone 17 Pro)"
	@echo ""
	@echo "Examples:"
	@echo "  make run-simulator SIMULATOR=\"iPhone 17 Pro Max\""
	@echo "  make test SIMULATOR=\"iPad Pro (12.9-inch)\""

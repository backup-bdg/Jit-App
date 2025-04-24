## JITEnabler iOS App Makefile
## A comprehensive set of commands to build, test, and manage the iOS app

# Configuration
PRODUCT_NAME = JITEnabler
WORKSPACE = $(PRODUCT_NAME).xcodeproj
SCHEME = $(PRODUCT_NAME)
CONFIGURATION ?= Debug
DEVICE ?= iPhone 15
OS_VERSION ?= latest
DERIVED_DATA_PATH = $(shell pwd)/DerivedData
BUILD_PATH = $(DERIVED_DATA_PATH)/Build/Products/$(CONFIGURATION)-iphoneos
XCODEBUILD = xcodebuild
DEVICE_ID ?= $(shell xcrun simctl list devices available -j | jq -r '.devices | to_entries | .[].value[] | select(.name=="$(DEVICE)") | .udid' | head -1)

# Default target
.PHONY: default
default: help

# Help command
.PHONY: help
help:
	@echo "JITEnabler iOS App Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  setup            - Install required dependencies"
	@echo "  clean            - Clean build artifacts"
	@echo "  build            - Build the app (Debug configuration by default)"
	@echo "  build-release    - Build the app in Release configuration"
	@echo "  test             - Run tests"
	@echo "  lint             - Run SwiftLint to check code quality"
	@echo "  archive          - Create an archive of the app"
	@echo "  export-ipa       - Export IPA from the archive"
	@echo "  run              - Run the app in the iOS Simulator"
	@echo "  devices          - List available iOS Simulator devices"
	@echo ""
	@echo "Configuration options:"
	@echo "  CONFIGURATION=Debug|Release        - Build configuration (default: Debug)"
	@echo "  DEVICE='iPhone 15'                 - Simulator device to use (default: iPhone 15)"
	@echo "  OS_VERSION=latest                  - iOS version (default: latest)"
	@echo ""

# Setup dependencies 
.PHONY: setup
setup:
	@echo "Installing dependencies..."
	@which brew > /dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	@which jq > /dev/null || brew install jq
	@which swiftlint > /dev/null || brew install swiftlint

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(DERIVED_DATA_PATH)
	@rm -rf $(PRODUCT_NAME).xcarchive
	@rm -rf build/
	$(XCODEBUILD) clean -project $(WORKSPACE) -scheme $(SCHEME) -configuration $(CONFIGURATION)

# Build the app
.PHONY: build
build:
	@echo "Building $(PRODUCT_NAME) ($(CONFIGURATION))..."
	$(XCODEBUILD) build -project $(WORKSPACE) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA_PATH) | xcpretty || $(XCODEBUILD) build -project $(WORKSPACE) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA_PATH)

# Build the app in Release configuration
.PHONY: build-release
build-release:
	@echo "Building $(PRODUCT_NAME) (Release)..."
	$(XCODEBUILD) build -project $(WORKSPACE) -scheme $(SCHEME) -configuration Release -derivedDataPath $(DERIVED_DATA_PATH) | xcpretty || $(XCODEBUILD) build -project $(WORKSPACE) -scheme $(SCHEME) -configuration Release -derivedDataPath $(DERIVED_DATA_PATH)

# Run tests
.PHONY: test
test:
	@echo "Running tests..."
	$(XCODEBUILD) test -project $(WORKSPACE) -scheme $(SCHEME) -destination "platform=iOS Simulator,name=$(DEVICE),OS=$(OS_VERSION)" -derivedDataPath $(DERIVED_DATA_PATH) | xcpretty || $(XCODEBUILD) test -project $(WORKSPACE) -scheme $(SCHEME) -destination "platform=iOS Simulator,name=$(DEVICE),OS=$(OS_VERSION)" -derivedDataPath $(DERIVED_DATA_PATH)

# Run SwiftLint
.PHONY: lint
lint:
	@echo "Running SwiftLint..."
	@which swiftlint > /dev/null || (echo "SwiftLint not installed. Run 'make setup' first." && exit 1)
	swiftlint

# Create an archive of the app
.PHONY: archive
archive:
	@echo "Creating archive..."
	$(XCODEBUILD) archive -project $(WORKSPACE) -scheme $(SCHEME) -configuration Release -archivePath $(PRODUCT_NAME).xcarchive | xcpretty || $(XCODEBUILD) archive -project $(WORKSPACE) -scheme $(SCHEME) -configuration Release -archivePath $(PRODUCT_NAME).xcarchive

# Export IPA from archive
.PHONY: export-ipa
export-ipa: archive
	@echo "Exporting IPA..."
	@mkdir -p build
	$(XCODEBUILD) -exportArchive -archivePath $(PRODUCT_NAME).xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build/ | xcpretty || $(XCODEBUILD) -exportArchive -archivePath $(PRODUCT_NAME).xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build/

# Run the app in the iOS Simulator
.PHONY: run
run: build
	@echo "Running $(PRODUCT_NAME) on $(DEVICE)..."
	@if [ -z "$(DEVICE_ID)" ]; then \
		echo "Error: Device '$(DEVICE)' not found. Run 'make devices' to see available devices."; \
		exit 1; \
	fi
	@xcrun simctl boot "$(DEVICE_ID)" 2>/dev/null || true
	xcrun simctl install "$(DEVICE_ID)" "$(DERIVED_DATA_PATH)/Build/Products/$(CONFIGURATION)-iphonesimulator/$(PRODUCT_NAME).app"
	xcrun simctl launch "$(DEVICE_ID)" $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$(DERIVED_DATA_PATH)/Build/Products/$(CONFIGURATION)-iphonesimulator/$(PRODUCT_NAME).app/Info.plist")

# List available iOS Simulator devices
.PHONY: devices
devices:
	@echo "Available iOS Simulator devices:"
	@xcrun simctl list devices available | grep -v "^--" | grep -v "^$$"

# Generate ExportOptions.plist if it doesn't exist
$(shell if [ ! -f ExportOptions.plist ]; then \
	echo '<?xml version="1.0" encoding="UTF-8"?>\
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\
<plist version="1.0">\
<dict>\
	<key>method</key>\
	<string>development</string>\
	<key>teamID</key>\
	<string>YOUR_TEAM_ID</string>\
	<key>compileBitcode</key>\
	<false/>\
	<key>uploadBitcode</key>\
	<false/>\
</dict>\
</plist>' > ExportOptions.plist; \
fi)

#!/bin/bash
# Script to build and package iOS app into IPA
# Updated for JIT Enabler app with improved error handling and diagnostics

set -e

# Configuration
XCODE_PROJECT="JITEnabler.xcodeproj"
XCODE_SCHEME="JITEnabler"
BUILD_DIR="build"
IPA_DIR="${BUILD_DIR}/ios/ipa"
DERIVED_DATA_PATH="${BUILD_DIR}/DerivedData"
LOG_DIR="${BUILD_DIR}/logs"
BUILD_VERSION="1.1.0"
BUILD_NUMBER=$(date "+%Y%m%d%H%M")

# Create directories
mkdir -p "${BUILD_DIR}"
mkdir -p "${IPA_DIR}"
mkdir -p "${DERIVED_DATA_PATH}"
mkdir -p "${LOG_DIR}"

echo "=== JIT Enabler Build Script ==="
echo "Build Version: ${BUILD_VERSION}"
echo "Build Number: ${BUILD_NUMBER}"
echo "Build Date: $(date)"
echo "==============================="

# Verify Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: xcodebuild command not found. Please install Xcode and make sure it's in your PATH."
    exit 1
fi

echo "=== Cleaning previous build artifacts ==="
rm -rf "${IPA_DIR}"/*
mkdir -p "${IPA_DIR}"

echo "=== Verifying project structure ==="
if [ ! -f "${XCODE_PROJECT}/project.pbxproj" ]; then
    echo "Error: Cannot find Xcode project at ${XCODE_PROJECT}"
    exit 1
fi

echo "=== Building for iOS simulator ==="
xcodebuild clean build \
    -project "${XCODE_PROJECT}" \
    -scheme "${XCODE_SCHEME}" \
    -configuration Debug \
    -sdk iphonesimulator \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -destination 'platform=iOS Simulator,name=iPhone 14,OS=latest' \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_ENTITLEMENTS="JITEnabler/JITEnabler.entitlements" \
    CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
    MARKETING_VERSION="${BUILD_VERSION}" | tee "${LOG_DIR}/build.log"

# Check if build was successful
if [ $? -ne 0 ]; then
    echo "Error: Build failed. See ${LOG_DIR}/build.log for details."
    exit 1
fi

# Find the app file
APP_PATH=$(find "${DERIVED_DATA_PATH}/Build/Products" -name "*.app" -type d | head -1)

if [ -z "${APP_PATH}" ]; then
    echo "Error: Could not find .app file in build products. Checking all directories..."
    find "${DERIVED_DATA_PATH}" -name "*.app" -type d
    exit 1
fi

echo "Found app at: ${APP_PATH}"

# Create Payload directory and copy app
echo "=== Creating IPA package ==="
mkdir -p "${IPA_DIR}/Payload"
cp -R "${APP_PATH}" "${IPA_DIR}/Payload/"

# Make sure the entitlements file is included
if [ -f "JITEnabler/JITEnabler.entitlements" ]; then
    echo "Copying entitlements file..."
    cp "JITEnabler/JITEnabler.entitlements" "${IPA_DIR}/Payload/$(basename "${APP_PATH}")/"
fi

# Update Info.plist in the app package
echo "=== Updating app metadata ==="
INFO_PLIST="${IPA_DIR}/Payload/$(basename "${APP_PATH}")/Info.plist"

if [ ! -f "$INFO_PLIST" ]; then
    echo "Error: Info.plist not found at $INFO_PLIST"
    exit 1
fi

# Update bundle identifier and version information
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.jitenabler.app" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${BUILD_VERSION}" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :MinimumOSVersion 15.0" "$INFO_PLIST"

# Add background fetch capability
/usr/libexec/PlistBuddy -c "Add :UIBackgroundModes array" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string fetch" "$INFO_PLIST" 2>/dev/null || true

# Create the IPA file
echo "=== Packaging IPA ==="
cd "${IPA_DIR}" && zip -r "JITEnabler_${BUILD_VERSION}_${BUILD_NUMBER}.ipa" Payload && rm -rf Payload

# Create symbolic link to the latest build
ln -sf "JITEnabler_${BUILD_VERSION}_${BUILD_NUMBER}.ipa" "${IPA_DIR}/JITEnabler.ipa"

echo "=== Build completed successfully ==="
echo "IPA file created at: ${IPA_DIR}/JITEnabler.ipa"
echo "Versioned IPA: ${IPA_DIR}/JITEnabler_${BUILD_VERSION}_${BUILD_NUMBER}.ipa"

# Verify the IPA file
if [ -f "${IPA_DIR}/JITEnabler.ipa" ]; then
    echo "=== IPA file details ==="
    ls -la "${IPA_DIR}/JITEnabler.ipa"
    echo "Size: $(du -h "${IPA_DIR}/JITEnabler.ipa" | cut -f1)"
    echo "SHA256: $(shasum -a 256 "${IPA_DIR}/JITEnabler.ipa" | cut -d' ' -f1)"
    
    # Print package contents summary
    echo "=== Package Contents ==="
    unzip -l "${IPA_DIR}/JITEnabler.ipa" | tail -n 10
else
    echo "Error: IPA file was not created"
    exit 1
fi

echo "=== Build Successful! ==="
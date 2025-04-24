#!/bin/bash
# Script to build the iOS app and create an IPA file

set -e  # Exit on error

# Display header
echo "====================================="
echo "JITEnabler iOS App Build Script"
echo "====================================="

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode command line tools not found. Please install Xcode."
    exit 1
fi

# Check if the Xcode project exists
if [ ! -d "JITEnabler.xcodeproj" ]; then
    echo "Error: JITEnabler.xcodeproj not found in the current directory."
    echo "Current directory: $(pwd)"
    echo "Files in current directory:"
    ls -la
    exit 1
fi

# Run the Makefile
echo "Building iOS app using Makefile.ios..."
make -f Makefile.ios info
make -f Makefile.ios clean
make -f Makefile.ios setup
make -f Makefile.ios build-ipa

# Verify the IPA was created
IPA_PATH="build/ios/ipa/JITEnabler.ipa"
if [ -f "$IPA_PATH" ]; then
    echo "====================================="
    echo "Build Successful!"
    echo "IPA file created at: $IPA_PATH"
    echo "File size: $(du -h $IPA_PATH | cut -f1)"
    echo "====================================="
else
    echo "====================================="
    echo "Error: IPA file not found at $IPA_PATH"
    echo "Build may have failed. Check the logs above for errors."
    echo "====================================="
    exit 1
fi
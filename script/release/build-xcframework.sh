#!/bin/bash

set -e

# Configuration
SCHEME="SendbirdAuthSDK"
FRAMEWORK_NAME="SendbirdAuthSDK"
BUILD_DIR="./build"
XCFRAMEWORK_NAME="${FRAMEWORK_NAME}.xcframework"
PROJECT_NAME="SendbirdAuthSDK.xcodeproj"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
rm -rf "$XCFRAMEWORK_NAME"
rm -rf "$PROJECT_NAME"

# Generate Xcode project using XCDGen
echo "🔧 Generating Xcode project with XCDGen..."
if ! command -v xcodegen &> /dev/null; then
    echo "❌ XCDGen not found. Installing via Homebrew..."
    brew install xcodegen
fi

xcodegen generate

# Create build directory
mkdir -p "$BUILD_DIR"

echo "📱 Building for iOS..."
xcodebuild archive \
  -project "$PROJECT_NAME" \
  -scheme "${SCHEME}_iOS" \
  -destination "generic/platform=iOS" \
  -archivePath "$BUILD_DIR/ios.xcarchive" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  -configuration Release

echo "📱 Building for iOS Simulator..."
xcodebuild archive \
  -project "$PROJECT_NAME" \
  -scheme "${SCHEME}_iOS" \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "$BUILD_DIR/ios-simulator.xcarchive" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  -configuration Release

echo "💻 Building for macOS..."
xcodebuild archive \
  -project "$PROJECT_NAME" \
  -scheme "${SCHEME}_macOS" \
  -destination "generic/platform=macOS" \
  -archivePath "$BUILD_DIR/macos.xcarchive" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  -configuration Release

echo "📦 Creating XCFramework..."
xcodebuild -create-xcframework \
  -framework "$BUILD_DIR/ios.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
  -framework "$BUILD_DIR/ios-simulator.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
  -framework "$BUILD_DIR/macos.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
  -output "$XCFRAMEWORK_NAME"

echo "✅ XCFramework created successfully: $XCFRAMEWORK_NAME"
echo "📊 Size:"
du -sh "$XCFRAMEWORK_NAME"

# Cleanup temporary Xcode project
echo ""
echo "🧹 Cleaning up temporary Xcode project..."
rm -rf "$PROJECT_NAME"

echo ""
echo "✅ Build complete!"
echo ""
echo "To use this framework:"
echo "1. Drag $XCFRAMEWORK_NAME into your Xcode project"
echo "2. Or add to Package.swift as binaryTarget"

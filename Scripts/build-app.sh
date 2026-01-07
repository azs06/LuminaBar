#!/bin/bash
set -e

APP_NAME="LuminaBar"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building $APP_NAME in release mode..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$MACOS/"

# Create Info.plist
cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>LuminaBar</string>
    <key>CFBundleDisplayName</key>
    <string>LuminaBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.lumina.bar</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>LuminaBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSLocalNetworkUsageDescription</key>
    <string>LuminaBar needs local network access to discover and control Yeelight devices.</string>
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS/PkgInfo"

echo "App bundle created: $APP_BUNDLE"
echo ""
echo "To install:"
echo "  cp -r $APP_BUNDLE /Applications/"
echo ""
echo "To create a DMG for distribution:"
echo "  hdiutil create -volname LuminaBar -srcfolder $APP_BUNDLE -ov -format UDZO LuminaBar.dmg"

#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$DIR/dist"
APP_DIR="$DIST_DIR/Duplix.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Building Duplix release binaries with Swift..."
cd "$DIR"
swift build -c release

echo "==> Creating Duplix.app bundle structure..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "==> Copying executables..."
cp "$DIR/.build/release/DuplixApp" "$MACOS_DIR/DuplixApp"
cp "$DIR/.build/release/duplix" "$MACOS_DIR/duplix"
chmod +x "$MACOS_DIR/DuplixApp"
chmod +x "$MACOS_DIR/duplix"

echo "==> Generating AppIcon.icns..."
swift "$DIR/scripts/generate_app_icon.swift" "$RESOURCES_DIR/AppIcon.icns"

echo "==> Writing Info.plist..."
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.duplix.app</string>
    <key>CFBundleName</key>
    <string>Duplix</string>
    <key>CFBundleDisplayName</key>
    <string>Duplix</string>
    <key>CFBundleExecutable</key>
    <string>DuplixApp</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "==> Codesigning Duplix.app..."
xattr -cr "$APP_DIR"
codesign --force --deep -s - "$APP_DIR"

echo "==> Duplix.app successfully assembled at: $APP_DIR"

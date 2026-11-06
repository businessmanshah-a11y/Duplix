#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_DIR="$DIR/VoiceMemo.app"

echo "🎙️ Building Duplix Voice Memo..."

# 1. Compile Swift binary
echo "  [1/5] Compiling Swift source..."
swiftc -O -parse-as-library "$DIR/main.swift" -o "$DIR/VoiceMemoApp"

# 2. Generate Icon if missing
if [ ! -f "$DIR/AppIcon.icns" ]; then
    echo "  [2/5] Generating AppIcon..."
    swift "$DIR/generate_icon.swift" "$DIR/AppIcon.icns"
else
    echo "  [2/5] AppIcon.icns already exists."
fi

# 3. Assemble .app bundle
echo "  [3/5] Assembling .app bundle..."
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$DIR/VoiceMemoApp" "$APP_DIR/Contents/MacOS/VoiceMemoApp"
cp "$DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

# 4. Code sign with entitlements
echo "  [4/5] Code signing with microphone entitlements..."
codesign --force --deep --sign - --entitlements "$DIR/entitlements.plist" "$APP_DIR"

# 5. Deploy to ~/Applications
echo "  [5/5] Deploying to ~/Applications/VoiceMemo.app..."
mkdir -p ~/Applications
rm -rf ~/Applications/VoiceMemo.app
cp -R "$APP_DIR" ~/Applications/

echo "✅ Build & Deploy complete!"

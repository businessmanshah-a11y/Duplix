#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$DIR/dist"
APP_PATH="$DIST_DIR/Duplix.app"
DMG_PATH="$DIST_DIR/Duplix-1.3.0.dmg"
STAGING_DIR="$DIST_DIR/dmg_staging"
INSTALL_LOCAL=false

for arg in "$@"; do
    if [ "$arg" = "--install" ]; then
        INSTALL_LOCAL=true
    fi
done

echo "==> Building Duplix.app..."
"$DIR/scripts/build_app.sh"

echo "==> Preparing DMG staging environment..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

echo "==> Copying Duplix.app to staging..."
cp -R "$APP_PATH" "$STAGING_DIR/Duplix.app"

echo "==> Creating /Applications drag-and-drop symlink..."
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Creating CLI installation helper..."
cat << 'EOF' > "$STAGING_DIR/Install CLI.command"
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
echo "==> Installing duplix CLI to /usr/local/bin..."
if [ -f "$DIR/Duplix.app/Contents/MacOS/duplix" ]; then
    sudo mkdir -p /usr/local/bin
    sudo cp "$DIR/Duplix.app/Contents/MacOS/duplix" /usr/local/bin/duplix
    sudo chmod +x /usr/local/bin/duplix
    echo "Successfully installed! Try running: duplix --help"
else
    echo "Error: duplix binary not found in Duplix.app"
fi
read -p "Press enter to exit..."
EOF
chmod +x "$STAGING_DIR/Install CLI.command"

echo "==> Generating compressed Apple Disk Image (DMG)..."
rm -f "$DMG_PATH"
rm -f "$DIST_DIR/Duplix-1.0.0.dmg" "$DIST_DIR/Duplix-1.1.0.dmg" "$DIST_DIR/Duplix-1.2.0.dmg"
hdiutil create \
    -volname "Duplix" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING_DIR"

echo "==> Updating distribution download locations..."
mkdir -p "$DIR/website/downloads"
mkdir -p "$DIR/docs/downloads"
cp -f "$DMG_PATH" "$DIR/website/downloads/Duplix.dmg"
cp -f "$DMG_PATH" "$DIR/docs/downloads/Duplix.dmg"

if [ "$INSTALL_LOCAL" = true ]; then
    echo "==> Updating /Applications/Duplix.app in place..."
    pkill -x DuplixApp 2>/dev/null || true
    pkill -x VoiceMemoApp 2>/dev/null || true
    sleep 0.4
    rm -rf /Applications/Duplix.app
    cp -R "$APP_PATH" /Applications/Duplix.app
    xattr -cr /Applications/Duplix.app 2>/dev/null || true
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Duplix.app 2>/dev/null || true
fi

# Remove temporary dist/Duplix.app so macOS Spotlight & LaunchServices do not register a duplicate app
rm -rf "$APP_PATH"

echo "==> DMG successfully created at: $DMG_PATH"
echo "==> File Size: $(ls -lh "$DMG_PATH" | awk '{print $5}')"
echo "==> SHA-256 Checksum:"
shasum -a 256 "$DMG_PATH"

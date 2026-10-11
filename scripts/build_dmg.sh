#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$DIR/dist"
APP_PATH="$DIST_DIR/Duplix.app"
DMG_PATH="$DIST_DIR/Duplix-1.0.0.dmg"
STAGING_DIR="$DIST_DIR/dmg_staging"

if [ ! -d "$APP_PATH" ]; then
    echo "==> Duplix.app not found. Building it first..."
    "$DIR/scripts/build_app.sh"
fi

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
hdiutil create \
    -volname "Duplix" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING_DIR"

echo "==> DMG successfully created at: $DMG_PATH"
echo "==> File Size: $(ls -lh "$DMG_PATH" | awk '{print $5}')"
echo "==> SHA-256 Checksum:"
shasum -a 256 "$DMG_PATH"

#!/usr/bin/env bash
# Duplix Official macOS Installer Script
# https://github.com/businessmanshah-a11y/Duplix
set -e

echo ""
echo "=========================================="
echo "      Duplix for macOS - Installer"
echo "  Free, Native macOS App Cloner"
echo "=========================================="
echo ""

# 1. Verify macOS
OS="$(uname -s)"
if [ "$OS" != "Darwin" ]; then
    echo "Error: Duplix is a native macOS application and cannot run on $OS."
    exit 1
fi

# 2. Check architecture
ARCH="$(uname -m)"
echo "Detected macOS on $ARCH architecture."

# 3. Download URLs
DMG_URL="https://businessmanshah-a11y.github.io/Duplix/downloads/Duplix.dmg"
FALLBACK_URL="https://raw.githubusercontent.com/businessmanshah-a11y/Duplix/main/docs/downloads/Duplix.dmg"

TEMP_DIR="$(mktemp -d /tmp/duplix-install-XXXXXX)"
DMG_FILE="$TEMP_DIR/Duplix.dmg"
MOUNT_DIR="$TEMP_DIR/mount"

cleanup() {
    if [ -d "$MOUNT_DIR" ]; then
        hdiutil detach "$MOUNT_DIR" -force 2>/dev/null || true
    fi
    rm -rf "$TEMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT

echo "--> Downloading Duplix (1.5 MB)..."
if curl -fsSL "$DMG_URL" -o "$DMG_FILE"; then
    echo "Downloaded from primary distribution."
else
    echo "Trying GitHub fallback distribution..."
    curl -fsSL "$FALLBACK_URL" -o "$DMG_FILE"
fi

echo "--> Mounting disk image..."
mkdir -p "$MOUNT_DIR"
hdiutil attach "$DMG_FILE" -mountpoint "$MOUNT_DIR" -nobrowse -quiet

echo "--> Installing Duplix to /Applications..."
if [ -d "/Applications/Duplix.app" ]; then
    echo "Updating existing /Applications/Duplix.app..."
    rm -rf "/Applications/Duplix.app"
fi
cp -R "$MOUNT_DIR/Duplix.app" /Applications/

# Install CLI tool to ~/.local/bin
if [ -f "/Applications/Duplix.app/Contents/MacOS/duplix" ]; then
    TARGET_CLI_DIR="${HOME}/.local/bin"
    mkdir -p "$TARGET_CLI_DIR"
    cp "/Applications/Duplix.app/Contents/MacOS/duplix" "$TARGET_CLI_DIR/duplix"
    chmod +x "$TARGET_CLI_DIR/duplix"
    echo "--> duplix CLI installed to $TARGET_CLI_DIR/duplix"
fi

echo "--> Clearing Gatekeeper quarantine..."
xattr -cr /Applications/Duplix.app 2>/dev/null || true

echo "--> Unmounting disk image..."
hdiutil detach "$MOUNT_DIR" -quiet

echo ""
echo "=========================================="
echo "  Duplix installed successfully!"
echo "  Location: /Applications/Duplix.app"
echo "=========================================="
echo ""
echo "Launching Duplix..."
open /Applications/Duplix.app || true

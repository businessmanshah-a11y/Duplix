#!/usr/bin/env bash
# Duplix Official macOS Installer & In-Place Updater
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

# 2. Check architecture and resolve true macOS home directory
ARCH="$(uname -m)"
echo "Detected macOS on $ARCH architecture."

REAL_HOME="$(dscl . -read "/Users/$(id -un)" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
if [ -z "$REAL_HOME" ] || [ ! -d "$REAL_HOME" ]; then
    REAL_HOME="$HOME"
fi

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

echo "--> Downloading Duplix..."
if curl -fsSL "$DMG_URL" -o "$DMG_FILE"; then
    echo "Downloaded from primary distribution."
else
    echo "Trying GitHub fallback distribution..."
    curl -fsSL "$FALLBACK_URL" -o "$DMG_FILE"
fi

echo "--> Mounting disk image..."
mkdir -p "$MOUNT_DIR"
hdiutil attach "$DMG_FILE" -mountpoint "$MOUNT_DIR" -nobrowse -quiet

echo "--> Stopping running Duplix instances (preserving all clones & data)..."
pkill -x DuplixApp 2>/dev/null || true
pkill -x VoiceMemoApp 2>/dev/null || true
sleep 0.5

echo "--> Updating /Applications/Duplix.app in place..."
if [ -d "/Applications/Duplix.app" ]; then
    echo "Replacing existing /Applications/Duplix.app..."
    rm -rf "/Applications/Duplix.app"
fi
cp -R "$MOUNT_DIR/Duplix.app" /Applications/

# Clean up any duplicate user-folder copies or legacy standalone VoiceMemo helper
if [ -d "$REAL_HOME/Applications/Duplix.app" ]; then
    echo "Removing duplicate $REAL_HOME/Applications/Duplix.app..."
    rm -rf "$REAL_HOME/Applications/Duplix.app"
fi
if [ -d "$REAL_HOME/Applications/VoiceMemo.app" ]; then
    echo "Removing legacy standalone $REAL_HOME/Applications/VoiceMemo.app (now built into Duplix)..."
    rm -rf "$REAL_HOME/Applications/VoiceMemo.app"
fi

# Install CLI tool to real ~/.local/bin
if [ -f "/Applications/Duplix.app/Contents/MacOS/duplix" ]; then
    TARGET_CLI_DIR="$REAL_HOME/.local/bin"
    mkdir -p "$TARGET_CLI_DIR"
    cp "/Applications/Duplix.app/Contents/MacOS/duplix" "$TARGET_CLI_DIR/duplix"
    chmod +x "$TARGET_CLI_DIR/duplix"
    echo "--> duplix CLI updated at $TARGET_CLI_DIR/duplix"
fi

echo "--> Clearing Gatekeeper quarantine & refreshing LaunchServices..."
xattr -cr /Applications/Duplix.app 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Duplix.app 2>/dev/null || true

echo "--> Unmounting disk image..."
hdiutil detach "$MOUNT_DIR" -quiet

echo ""
echo "=========================================="
echo "  Duplix installed/updated successfully!"
echo "  Location: /Applications/Duplix.app"
echo "  All existing clones & data preserved."
echo "=========================================="
echo ""
echo "Launching Duplix..."
env -u CFFIXED_USER_HOME HOME="$REAL_HOME" open /Applications/Duplix.app || true

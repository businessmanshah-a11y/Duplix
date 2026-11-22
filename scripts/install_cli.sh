#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Building duplix CLI in release mode (Universal 2: arm64 + x86_64)..."
cd "$DIR"
swift build -c release --product duplix --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --product duplix --arch arm64 --arch x86_64 --show-bin-path)"

if [ ! -f "$BIN_DIR/duplix" ]; then
    if [ -f "$DIR/.build/apple/Products/Release/duplix" ]; then
        BIN_PATH="$DIR/.build/apple/Products/Release/duplix"
    elif [ -f "$DIR/.build/out/Products/Release/duplix" ]; then
        BIN_PATH="$DIR/.build/out/Products/Release/duplix"
    elif [ -f "$DIR/.build/release/duplix" ]; then
        BIN_PATH="$DIR/.build/release/duplix"
    fi
else
    BIN_PATH="$BIN_DIR/duplix"
fi
TARGET_DIR="${HOME}/.local/bin"

mkdir -p "$TARGET_DIR"
cp "$BIN_PATH" "$TARGET_DIR/duplix"
chmod +x "$TARGET_DIR/duplix"

echo "==> duplix CLI successfully installed to: $TARGET_DIR/duplix"
if [[ ":$PATH:" != *":$TARGET_DIR:"* ]]; then
    echo "Note: Make sure $TARGET_DIR is in your PATH: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
echo "==> Test run:"
"$TARGET_DIR/duplix" --help

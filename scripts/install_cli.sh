#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Building duplix CLI in release mode..."
cd "$DIR"
swift build -c release --product duplix

BIN_PATH="$DIR/.build/release/duplix"
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

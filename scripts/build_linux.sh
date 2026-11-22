#!/usr/bin/env bash
# Duplix Linux Build & Packaging Script
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$DIR/dist/linux"
RELEASE_DIR="$DIR/.build/release"

echo "==> Building Duplix for Linux..."
cd "$DIR"

# Build release CLI
swift build -c release --product duplix

mkdir -p "$DIST_DIR"
cp "$RELEASE_DIR/duplix" "$DIST_DIR/duplix"
chmod +x "$DIST_DIR/duplix"

echo "==> Packaging Linux tarball..."
TARBALL="$DIST_DIR/duplix-linux-$(uname -m).tar.gz"
tar -czf "$TARBALL" -C "$DIST_DIR" duplix

echo "==> Linux build complete at: $TARBALL"

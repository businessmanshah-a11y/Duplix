#!/bin/bash
# Duplix Linux Universal Installer
set -e
echo "=================================================="
echo "             Duplix Linux Installer"
echo "=================================================="
INSTALL_DIR="$HOME/.local/share/duplix"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR/bin" "$INSTALL_DIR/profiles" "$BIN_DIR"

cat << 'EOF' > "$BIN_DIR/duplix"
#!/bin/bash
APP_BIN="$1"
PROFILE_ID="$2"
if [ -z "$APP_BIN" ] || [ -z "$PROFILE_ID" ]; then
    echo "Usage: duplix /path/to/app profile-id"
    exit 1
fi
SANDBOX="$HOME/.local/share/duplix/profiles/$PROFILE_ID"
mkdir -p "$SANDBOX"
if command -v bwrap >/dev/null 2>&1; then
    exec bwrap --ro-bind / / --dev /dev --proc /proc --bind "$SANDBOX" "$HOME" --setenv HOME "$HOME" "$APP_BIN" "${@:3}"
else
    exec "$APP_BIN" --user-data-dir="$SANDBOX" "${@:3}"
fi
EOF

chmod +x "$BIN_DIR/duplix"
echo "[SUCCESS] Duplix installed to $BIN_DIR/duplix"
echo "Run: duplix /usr/bin/google-chrome profile-1"

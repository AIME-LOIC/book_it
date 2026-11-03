#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_DIR="$PROJECT_DIR/build/linux/x64/release/bundle"
ICON_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/512x512/apps"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

if [[ ! -x "$BUNDLE_DIR/bookit" ]]; then
  echo "BookIt Linux release bundle not found. Building it now..."
  (cd "$PROJECT_DIR" && flutter build linux --release)
fi

mkdir -p "$ICON_DIR" "$APP_DIR"
install -m 0644 "$PROJECT_DIR/assets/icon.png" "$ICON_DIR/bookit.png"

cat > "$APP_DIR/bookit.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=BookIt
Comment=BookIt bus booking and trip management
Exec="$BUNDLE_DIR/bookit"
Icon=$ICON_DIR/bookit.png
Terminal=false
Categories=Office;Utility;
StartupNotify=true
StartupWMClass=rw.onepercent.bookit
EOF

chmod 0644 "$APP_DIR/bookit.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APP_DIR" || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor" || true
fi

echo "BookIt launcher and icon installed for the current user."
echo "Find BookIt in your Kali applications menu, or run: "$BUNDLE_DIR/bookit""

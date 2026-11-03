#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_DIR="$PROJECT_DIR/build/linux/x64/release/bundle"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_ROOT="$HOME/.local/opt/bookit"
VERSION_DIR="$APP_ROOT/releases/local"
ICON_DIR="$DATA_DIR/icons/hicolor/512x512/apps"
APP_DIR="$DATA_DIR/applications"
BIN_DIR="$HOME/.local/bin"

if [[ ! -x "$BUNDLE_DIR/bookit" ]]; then
  echo "BookIt Linux release bundle not found. Building it now..."
  (cd "$PROJECT_DIR" && flutter build linux --release)
fi

if [[ ! -x "$BUNDLE_DIR/bookit" ]]; then
  echo "Build did not produce $BUNDLE_DIR/bookit" >&2
  exit 1
fi

mkdir -p "$VERSION_DIR" "$ICON_DIR" "$APP_DIR" "$BIN_DIR"
cp -a "$BUNDLE_DIR/." "$VERSION_DIR/"
printf '%s\n' "local" > "$VERSION_DIR/.bookit-version"
install -m 0644 "$PROJECT_DIR/assets/icon.png" "$ICON_DIR/bookit.png"

ln -s "$VERSION_DIR" "$APP_ROOT/current.new"
mv -Tf "$APP_ROOT/current.new" "$APP_ROOT/current"

cat > "$APP_DIR/bookit.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=BookIt
Comment=BookIt bus booking and trip management
Exec=$APP_ROOT/current/bookit
Icon=$ICON_DIR/bookit.png
Terminal=false
Categories=Office;Utility;
StartupNotify=true
StartupWMClass=rw.onepercent.bookit
EOF
chmod 0644 "$APP_DIR/bookit.desktop"

install -m 0755 "$PROJECT_DIR/scripts/update-linux.sh" "$APP_ROOT/update-linux.sh"
cat > "$BIN_DIR/bookit-update" <<EOF
#!/usr/bin/env bash
exec "$APP_ROOT/update-linux.sh" "\$@"
EOF
chmod 0755 "$BIN_DIR/bookit-update"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APP_DIR" || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "$DATA_DIR/icons/hicolor" || true
fi

echo "BookIt installed for the current user."
echo "Launch it from the applications menu, or run: $APP_ROOT/current/bookit"
echo "To install future GitHub releases, run: $BIN_DIR/bookit-update"

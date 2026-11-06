#!/usr/bin/env bash
set -euo pipefail

OWNER="AIME-LOIC"
REPO="book_it"
SCRIPT_SOURCE="$(readlink -f "${BASH_SOURCE[0]}")"
API_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases/latest"
APP_ROOT="$HOME/.local/opt/bookit"
APP_ROOT="$(mkdir -p "$APP_ROOT" && cd "$APP_ROOT" && pwd -P)"
RELEASES_DIR="$APP_ROOT/releases"
BIN_DIR="${HOME}/.local/bin"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
ICON_DIR="$DATA_DIR/icons/hicolor/512x512/apps"
DESKTOP_DIR="$DATA_DIR/applications"
ASSET_NAME="bookit-linux-x86_64.tar.gz"
CHECKSUM_NAME="$ASSET_NAME.sha256"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

for command_name in curl python3 tar sha256sum; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
done

mkdir -p "$RELEASES_DIR" "$BIN_DIR" "$ICON_DIR" "$DESKTOP_DIR"

echo "Checking the latest BookIt Linux release..."
curl --fail --location --silent --show-error \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$API_URL" -o "$TMP_DIR/release.json"

readarray -t RELEASE_INFO < <(python3 - "$TMP_DIR/release.json" "$ASSET_NAME" "$CHECKSUM_NAME" <<'PY'
import json, re, sys
with open(sys.argv[1], encoding="utf-8") as f:
    release = json.load(f)
tag = release.get("tag_name", "")
if not re.fullmatch(r"v?[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?", tag):
    raise SystemExit("GitHub release has an invalid version tag.")
assets = {a.get("name"): a.get("browser_download_url") for a in release.get("assets", [])}
for name in sys.argv[2:]:
    url = assets.get(name)
    if not url or not url.startswith("https://"):
        raise SystemExit(f"Release is missing required asset: {name}")
    print(url)
print(tag)
PY
)
if [[ ${#RELEASE_INFO[@]} -lt 3 ]]; then
  echo "ERROR: Release assets are missing or invalid."
  echo "Expected: bookit-linux-x86_64.tar.gz and its .sha256 checksum."
  echo "Check the GitHub Linux release workflow."
  exit 1
fi
ARCHIVE_URL="${RELEASE_INFO[0]}"
CHECKSUM_URL="${RELEASE_INFO[1]}"
VERSION="${RELEASE_INFO[2]}"
VERSION_DIR="$RELEASES_DIR/$VERSION"
CURRENT_VERSION=""
if [[ -f "$APP_ROOT/current/.bookit-version" ]]; then
  CURRENT_VERSION="$(cat "$APP_ROOT/current/.bookit-version")"
fi

if [[ "$CURRENT_VERSION" == "$VERSION" && -x "$APP_ROOT/current/bookit" ]]; then
  echo "BookIt $VERSION is already installed."
  exit 0
fi

echo "Downloading BookIt $VERSION..."
curl --fail --location --silent --show-error "$ARCHIVE_URL" -o "$TMP_DIR/$ASSET_NAME"
curl --fail --location --silent --show-error "$CHECKSUM_URL" -o "$TMP_DIR/$CHECKSUM_NAME"

EXPECTED_HASH="$(awk 'NR==1 {print $1}' "$TMP_DIR/$CHECKSUM_NAME")"
ACTUAL_HASH="$(sha256sum "$TMP_DIR/$ASSET_NAME" | awk '{print $1}')"
if [[ -z "$EXPECTED_HASH" || "$EXPECTED_HASH" != "$ACTUAL_HASH" ]]; then
  echo "Checksum verification failed. The existing BookIt installation was not changed." >&2
  exit 1
fi

mkdir "$TMP_DIR/extracted"
tar -xzf "$TMP_DIR/$ASSET_NAME" -C "$TMP_DIR/extracted"
if [[ ! -x "$TMP_DIR/extracted/bookit/bookit" || ! -f "$TMP_DIR/extracted/bookit-icon.png" ]]; then
  echo "Downloaded release does not contain the expected BookIt files." >&2
  exit 1
fi

rm -rf "$VERSION_DIR"
mkdir -p "$VERSION_DIR"
cp -a "$TMP_DIR/extracted/bookit/." "$VERSION_DIR/"
printf '%s\n' "$VERSION" > "$VERSION_DIR/.bookit-version"
install -m 0644 "$TMP_DIR/extracted/bookit-icon.png" "$ICON_DIR/bookit.png"

# Atomically switch the launcher target only after the new version is complete.
rm -f "$APP_ROOT/current.new"
ln -s "$VERSION_DIR" "$APP_ROOT/current.new"
mv -Tf "$APP_ROOT/current.new" "$APP_ROOT/current"

cat > "$DESKTOP_DIR/bookit.desktop" <<EOF
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
chmod 0644 "$DESKTOP_DIR/bookit.desktop"

if [[ "$SCRIPT_SOURCE" != "$APP_ROOT/update-linux.sh" ]]; then
  install -m 0755 "$SCRIPT_SOURCE" "$APP_ROOT/update-linux.sh"
fi

cat > "$BIN_DIR/bookit-update" <<EOF
#!/usr/bin/env bash
exec "$APP_ROOT/update-linux.sh" "\$@"
EOF
chmod 0755 "$BIN_DIR/bookit-update"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_DIR" || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "$DATA_DIR/icons/hicolor" || true
fi

echo "BookIt updated successfully to $VERSION."
echo "Close and reopen BookIt to use the new version."

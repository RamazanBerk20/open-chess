#!/usr/bin/env bash
# Build a portable AppImage from the Flutter Linux release bundle.
# Requires $VERSION in the environment. Run from the repo root.
set -euo pipefail

BUNDLE="build/linux/x64/release/bundle"
APPDIR="AppDir"
VERSION="${VERSION:?set VERSION}"

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
# Flutter resolves data/ and lib/ next to the executable, so keep the whole
# bundle together under usr/bin.
cp -r "$BUNDLE"/. "$APPDIR/usr/bin/"
# Desktop file id must equal the GTK application id (Wayland app_id match).
cp installers/linux/open-chess.desktop "$APPDIR/com.ramazan.openchess.desktop"
cp assets/icon/open-chess.png "$APPDIR/open-chess.png"

cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/bin/lib:${LD_LIBRARY_PATH:-}"
exec "$HERE/usr/bin/open-chess" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Pinned release (immutable tag, not "continuous"); its SHA-256 is committed in
# installers/linux/appimagetool.sha256 and checked before the tool ever runs.
# To upgrade: change the tag here and the hash in that file together.
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage"
if [ ! -x ./appimagetool ]; then
  wget -q "$APPIMAGETOOL_URL" -O appimagetool
fi
sha256sum -c installers/linux/appimagetool.sha256
chmod +x appimagetool

# No FUSE on CI runners → extract-and-run.
ARCH=x86_64 ./appimagetool --appimage-extract-and-run "$APPDIR" "open-chess-${VERSION}-x86_64.AppImage"
echo "Built open-chess-${VERSION}-x86_64.AppImage"

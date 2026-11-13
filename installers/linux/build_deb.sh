#!/usr/bin/env bash
# Build a .deb from the Flutter Linux release bundle. Requires $VERSION.
# Run from the repo root.
set -euo pipefail

BUNDLE="build/linux/x64/release/bundle"
VERSION="${VERSION:?set VERSION}"
PKG="deb/open-chess"

rm -rf deb
mkdir -p "$PKG/DEBIAN" "$PKG/opt/open-chess" "$PKG/usr/bin" \
         "$PKG/usr/share/applications" \
         "$PKG/usr/share/icons/hicolor/512x512/apps"

cp -r "$BUNDLE"/. "$PKG/opt/open-chess/"

cat > "$PKG/usr/bin/open-chess" <<'EOF'
#!/bin/sh
exec /opt/open-chess/open-chess "$@"
EOF
chmod +x "$PKG/usr/bin/open-chess"

cp installers/linux/open-chess.desktop "$PKG/usr/share/applications/com.ramazan.openchess.desktop"
cp assets/icon/open-chess.png "$PKG/usr/share/icons/hicolor/512x512/apps/open-chess.png"

cat > "$PKG/DEBIAN/control" <<EOF
Package: open-chess
Version: ${VERSION}
Section: games
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libstdc++6, libblkid1
Maintainer: Ramazan Berk Şirin <ramazanberksirin@protonmail.com>
Homepage: https://github.com/RamazanBerk20/open-chess
Description: Open Chess with variants, AI, LAN and puzzles
 A cross-platform Open Chess app (Flutter UI over a Rust rules+AI engine) with
 Fog of War, Bughouse, 4-player, Crazyhouse, Atomic and more, plus LAN play,
 puzzles and post-game analysis.
EOF

dpkg-deb --build --root-owner-group "$PKG" "open-chess_${VERSION}_amd64.deb"
echo "Built open-chess_${VERSION}_amd64.deb"

# AUR packages

Three flavours (each its own AUR repo). All install `/usr/bin/open-chess`; they
`conflict` so only one is installed at a time.

| Package | Build | When to use |
|---------|-------|-------------|
| [`open-chess-bin`](open-chess-bin/) | installs the prebuilt GitHub release tarball | fastest, no toolchain |
| [`open-chess`](open-chess/) | builds the tagged release from source | reproducible source build |
| [`open-chess-git`](open-chess-git/) | builds the latest `main` from source | bleeding edge |

`open-chess` / `open-chess-git` build with Flutter + Rust, so they need
`makedepends=(flutter rust clang cmake ninja pkgconf git)`. If your AUR `flutter`
package is named differently (e.g. `flutter-bin`), adjust that one makedepend.

## Publish / update (uses your existing `~/.ssh/aur` key)

```fish
fish aur/publish-aur.fish open-chess-bin   # or: open-chess | open-chess-git
```

The script: ensures the ssh-config entry → tests AUR auth → clones the package
repo → copies its `PKGBUILD`/`.SRCINFO` → `updpkgsums` + regenerates `.SRCINFO`
→ `makepkg -df --noconfirm` (builds to verify without installing) → shows the
diff → asks before pushing
(to `master`, which the AUR requires).

> You only need ONE key for all packages — AUR keys are per-account. No new keys.

## Manual (per package)

```fish
git clone ssh://aur@aur.archlinux.org/open-chess.git ~/aur-open-chess
cd ~/aur-open-chess
cp ~/Belgeler/AI/Code/open-chess/aur/open-chess/{PKGBUILD,.SRCINFO} .
updpkgsums; and makepkg --printsrcinfo > .SRCINFO
makepkg -df --noconfirm
git add -A; and git commit -m "open-chess 1.1.0"; and git branch -M master; and git push origin master
```

## New release

After tagging a new `vX.Y.Z` (CI builds the assets):

- `open-chess-bin` / `open-chess`: bump `pkgver` (reset `pkgrel=1`), then re-run the script.
- `open-chess-git`: nothing to bump — `pkgver()` tracks git; just re-run to refresh.

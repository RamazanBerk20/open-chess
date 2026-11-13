# Changelog

## [1.2.0] - 2026-11-13

### Compatibility notes (read first)
- **LAN protocol is now version 8.** Both devices must run 1.2.0; 1.1.0 cannot play over LAN with 1.2.0 (the older side is shown an update message).
- FEN validation is stricter. Stale castling rights and en-passant squares are repaired automatically instead of crashing; genuinely invalid positions are rejected with an error.
- Old Atomic-variant saves from earlier versions may open only partially.
- Not tested on real hardware: the Android build and two-device LAN play (including four-player and Bughouse LAN) were only exercised by automated tests.

### Added
- Autosave and resume of the game in progress.
- Pause for games.
- PGN and FEN import.
- Setting to turn off the update check at launch (Settings; the check is one GitHub request at startup).
- Quiet GitHub Sponsors link.
- Updated translations in all 10 languages.

### Changed
- LAN protocol version 8 (see above).
- Four-player bots are deterministic and run asynchronously.
- Release CI now runs analysis and tests before building anything, and the AppImage build tool is pinned by SHA-256.

### Fixed
- Saved games could be lost; saves are now written atomically.
- LAN move ownership checks: a player can no longer move the other side's pieces, and the network reader is cancel-safe.
- Crashes on malformed FEN input.
- AI searches finishing after a game was replaced or reset; they are now bound to their session.
- End-of-game handling (terminations are reported consistently).

### Security
- Stricter validation of data received over LAN and of imported positions.
- Release tooling downloads are verified against a committed SHA-256 before execution.

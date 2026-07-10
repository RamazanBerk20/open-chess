import 'dart:typed_data';

import 'package:open_chess/src/rust/api/net.dart';
import 'package:open_chess/src/state/player_profile.dart';
import 'package:open_chess/src/state/profile_avatar_service.dart';

/// Converts the persisted profile to the bounded bridge DTO used by LAN calls.
PlayerProfileWire lanProfileWire(PlayerProfile profile) => PlayerProfileWire(
  username: profile.username,
  avatarBytes: profile.avatarBytes ?? Uint8List(0),
);

/// Converts a validated remote profile into the same model used by the UI.
PlayerProfile lanProfileFromWire(PlayerProfileWire profile) {
  final raw = profile.avatarBytes;
  Uint8List? avatar;
  if (raw.isNotEmpty) {
    try {
      // Remote avatars are normalized again before they reach MemoryImage. This
      // verifies decodability and caps dimensions before any full raster decode.
      avatar = normalizeProfileAvatar(raw);
    } on ProfileAvatarException {
      avatar = null;
    } catch (_) {
      avatar = null;
    }
  }
  return PlayerProfile.normalized(
    username: profile.username,
    avatarBytes: avatar,
  );
}

import 'dart:typed_data';

import 'package:image/image.dart' as image;

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
  if (raw.isNotEmpty && remoteAvatarCheap(raw)) {
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

/// Largest side a peer's avatar may declare. Ours are 96 px; this keeps the
/// UI-isolate decode of up to four remote avatars trivially cheap.
const maxRemoteAvatarSide = 256;

/// A remote avatar is decoded only if it is a small JPEG (what this app
/// sends) whose header declares at most [maxRemoteAvatarSide] per side.
bool remoteAvatarCheap(Uint8List bytes) {
  if (!PlayerProfile.isValidAvatar(bytes)) return false;
  try {
    final info = image.JpegDecoder().startDecode(bytes);
    return info != null &&
        info.width > 0 &&
        info.height > 0 &&
        info.width <= maxRemoteAvatarSide &&
        info.height <= maxRemoteAvatarSide;
  } catch (_) {
    return false;
  }
}

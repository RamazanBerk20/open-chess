import 'dart:convert';
import 'dart:typed_data';

/// Local identity shared by future network and game surfaces.
///
/// A missing avatar represents the built-in pawn avatar. Custom avatars are
/// normalized to a compact JPEG before they enter this model, which keeps the
/// persisted value and eventual LAN payloads bounded.
class PlayerProfile {
  static const String defaultUsername = 'player';
  static const int maxUsernameLength = 24;
  static const int avatarSize = 96;
  // Matches the LAN protocol cap. Four-seat starts carry four profiles in one
  // bounded JSON message, so avatars must remain compact after Base64 encoding.
  static const int maxAvatarBytes = 8 * 1024;

  final String username;
  final Uint8List? _avatarBytes;

  const PlayerProfile({this.username = defaultUsername}) : _avatarBytes = null;

  PlayerProfile._({required this.username, Uint8List? avatarBytes})
    : _avatarBytes = avatarBytes == null
          ? null
          : Uint8List.fromList(avatarBytes);

  /// `null` means that the built-in pawn avatar should be rendered.
  Uint8List? get avatarBytes {
    final bytes = _avatarBytes;
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  bool get hasCustomAvatar => _avatarBytes != null;

  /// Encoded form intended for bounded wire payloads as well as persistence.
  String? get avatarBase64 {
    final bytes = _avatarBytes;
    return bytes == null ? null : base64Encode(bytes);
  }

  PlayerProfile copyWith({
    String? username,
    Uint8List? avatarBytes,
    bool clearAvatar = false,
  }) => PlayerProfile._(
    username: sanitizeUsername(username ?? this.username),
    avatarBytes: clearAvatar ? null : (avatarBytes ?? _avatarBytes),
  );

  Map<String, dynamic> toJson() {
    final bytes = _avatarBytes;
    return {
      'username': sanitizeUsername(username),
      if (bytes != null) 'avatarBase64': base64Encode(bytes),
    };
  }

  /// Parses persisted or future wire data defensively. Invalid and oversized
  /// avatars fall back to the pawn rather than making settings unreadable.
  factory PlayerProfile.fromJson(Object? value) {
    if (value is! Map) return const PlayerProfile();
    final rawUsername = value['username'];
    final rawAvatar = value['avatarBase64'] ?? value['avatar'];
    Uint8List? avatar;
    if (rawAvatar is String && rawAvatar.isNotEmpty) {
      try {
        final bytes = Uint8List.fromList(base64Decode(rawAvatar));
        if (isValidAvatar(bytes)) avatar = bytes;
      } on FormatException {
        // A profile must remain usable when a previous avatar was corrupted.
      }
    }
    return PlayerProfile._(
      username: sanitizeUsername(rawUsername is String ? rawUsername : ''),
      avatarBytes: avatar,
    );
  }

  /// Creates a profile only from values suitable for local storage and LAN.
  factory PlayerProfile.normalized({
    String? username,
    Uint8List? avatarBytes,
  }) => PlayerProfile._(
    username: sanitizeUsername(username ?? defaultUsername),
    avatarBytes: isValidAvatar(avatarBytes) ? avatarBytes : null,
  );

  static bool isValidAvatar(Uint8List? bytes) {
    if (bytes == null) return true;
    return bytes.length >= 4 &&
        bytes.length <= maxAvatarBytes &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
  }

  static String sanitizeUsername(String value) {
    final withoutControls = value.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ');
    final collapsed = withoutControls.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty) return defaultUsername;
    return String.fromCharCodes(collapsed.runes.take(maxUsernameLength));
  }

  @override
  bool operator ==(Object other) =>
      other is PlayerProfile &&
      username == other.username &&
      _bytesEqual(_avatarBytes, other._avatarBytes);

  @override
  int get hashCode =>
      Object.hash(username, Object.hashAll(_avatarBytes ?? const []));
}

bool _bytesEqual(Uint8List? a, Uint8List? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

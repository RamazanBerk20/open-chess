import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import 'package:open_chess/src/state/player_profile.dart';
import 'package:open_chess/src/state/profile_avatar_service.dart';
import 'package:open_chess/src/state/settings.dart';

void main() {
  group('PlayerProfile', () {
    test('defaults to the persisted player identity and pawn avatar', () {
      const profile = PlayerProfile();

      expect(profile.username, PlayerProfile.defaultUsername);
      expect(profile.avatarBytes, isNull);
      expect(profile.hasCustomAvatar, isFalse);
    });

    test('normalizes usernames and protects avatar payload bounds', () {
      final tooLong = List<String>.filled(30, 'a').join();
      final profile = PlayerProfile.normalized(
        username: '  $tooLong\n',
        avatarBytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
      );

      expect(
        profile.username,
        List<String>.filled(PlayerProfile.maxUsernameLength, 'a').join(),
      );
      expect(profile.hasCustomAvatar, isTrue);
      expect(
        PlayerProfile.normalized(
          avatarBytes: Uint8List(PlayerProfile.maxAvatarBytes + 1),
        ).hasCustomAvatar,
        isFalse,
      );
    });

    test('removes every LAN-forbidden control character from usernames', () {
      expect(
        PlayerProfile.sanitizeUsername(' Ada\u0000\t\nPlayer '),
        'Ada Player',
      );
    });

    test('recovers safely from corrupt persisted avatars', () {
      final profile = PlayerProfile.fromJson(<String, dynamic>{
        'username': '  Ada  ',
        'avatarBase64': base64Encode(<int>[1, 2, 3]),
      });

      expect(profile.username, 'Ada');
      expect(profile.hasCustomAvatar, isFalse);
    });

    test('migrates profile-free settings to the default identity', () {
      final settings = Settings.fromJson(<String, dynamic>{});

      expect(settings.playerProfile.username, PlayerProfile.defaultUsername);
      expect(settings.playerProfile.hasCustomAvatar, isFalse);
    });

    test('normalizes a persisted custom avatar before exposing it', () {
      final source = image.Image(width: 180, height: 120);
      final settings = Settings.fromJson(<String, dynamic>{
        'playerProfile': <String, dynamic>{
          'username': 'Ada',
          'avatarBase64': base64Encode(image.encodeJpg(source)),
        },
      });
      final avatar = settings.playerProfile.avatarBytes;
      final decoded = avatar == null ? null : image.decodeJpg(avatar);

      expect(avatar, isNotNull);
      expect(decoded, isNotNull);
      expect(decoded!.width, PlayerProfile.avatarSize);
      expect(decoded.height, PlayerProfile.avatarSize);
    });
  });

  group('normalizeProfileAvatar', () {
    test('centre-crops and bounds the selected image as a JPEG', () {
      final source = image.Image(width: 180, height: 120);
      final avatar = normalizeProfileAvatar(
        Uint8List.fromList(image.encodePng(source)),
      );
      final decoded = image.decodeJpg(avatar);

      expect(avatar.length, lessThanOrEqualTo(PlayerProfile.maxAvatarBytes));
      expect(avatar.take(3), orderedEquals(<int>[0xff, 0xd8, 0xff]));
      expect(decoded, isNotNull);
      expect(decoded!.width, PlayerProfile.avatarSize);
      expect(decoded.height, PlayerProfile.avatarSize);
    });

    test('rejects an empty source', () {
      expect(
        () => normalizeProfileAvatar(Uint8List(0)),
        throwsA(isA<ProfileAvatarException>()),
      );
    });
  });
}

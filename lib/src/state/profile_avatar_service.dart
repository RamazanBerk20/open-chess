import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:image/image.dart' as image;

import 'package:open_chess/src/state/player_profile.dart';

/// The largest source file accepted before image decoding. The final profile
/// avatar is always much smaller than this limit.
const int _maxSourceAvatarBytes = 8 * 1024 * 1024;
const int _maxSourceAvatarPixels = 4 * 1024 * 1024;
const int _maxSourceAvatarDimension = 4096;

class ProfileAvatarException implements Exception {
  final String message;
  const ProfileAvatarException(this.message);

  @override
  String toString() => message;
}

/// Opens the platform's image chooser and returns a square profile JPEG.
/// Returning `null` means that the user cancelled the picker.
Future<Uint8List?> pickProfileAvatar() async {
  const imageTypes = XTypeGroup(
    label: 'Images',
    extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
  );
  final file = await openFile(acceptedTypeGroups: const [imageTypes]);
  if (file == null) return null;
  return normalizeProfileAvatar(await file.readAsBytes());
}

/// Centre-crops any supported image and encodes a small, portable JPEG.
Uint8List normalizeProfileAvatar(Uint8List source) {
  if (source.isEmpty || source.length > _maxSourceAvatarBytes) {
    throw const ProfileAvatarException('Selected image is too large.');
  }

  final decoder = image.findDecoderForData(source);
  image.DecodeInfo? info;
  try {
    info = decoder?.startDecode(source);
  } catch (_) {
    throw const ProfileAvatarException(
      'Selected file is not a supported image.',
    );
  }
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width > _maxSourceAvatarDimension ||
      info.height > _maxSourceAvatarDimension ||
      info.width * info.height > _maxSourceAvatarPixels) {
    throw const ProfileAvatarException(
      'Selected file is not a supported image.',
    );
  }

  image.Image? decoded;
  try {
    decoded = image.decodeImage(source);
  } catch (_) {
    throw const ProfileAvatarException(
      'Selected file is not a supported image.',
    );
  }
  if (decoded == null) {
    throw const ProfileAvatarException(
      'Selected file is not a supported image.',
    );
  }

  final side = decoded.width < decoded.height ? decoded.width : decoded.height;
  final cropped = image.copyCrop(
    decoded,
    x: (decoded.width - side) ~/ 2,
    y: (decoded.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final resized = image.copyResize(
    cropped,
    width: PlayerProfile.avatarSize,
    height: PlayerProfile.avatarSize,
    interpolation: image.Interpolation.average,
  );

  for (final quality in <int>[85, 75, 65, 55, 45, 35]) {
    final encoded = Uint8List.fromList(
      image.encodeJpg(resized, quality: quality),
    );
    if (encoded.length <= PlayerProfile.maxAvatarBytes) return encoded;
  }
  throw const ProfileAvatarException('Selected image could not be compressed.');
}

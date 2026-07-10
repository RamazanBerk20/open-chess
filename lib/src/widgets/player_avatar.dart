import 'package:flutter/material.dart';

import 'package:open_chess/src/state/player_profile.dart';

/// Consistent player avatar rendering for settings, LAN, and game surfaces.
class PlayerAvatar extends StatelessWidget {
  final PlayerProfile profile;
  final double radius;
  final Color? backgroundColor;

  const PlayerAvatar({
    super.key,
    required this.profile,
    this.radius = 24,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final avatar = profile.avatarBytes;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? colors.secondaryContainer,
      foregroundColor: colors.onSecondaryContainer,
      foregroundImage: avatar == null ? null : MemoryImage(avatar),
      child: avatar == null
          ? Text(
              '♟',
              style: TextStyle(
                fontFamily: 'ChessGlyphs',
                fontSize: radius * 1.35,
                height: 1,
              ),
            )
          : null,
    );
  }
}

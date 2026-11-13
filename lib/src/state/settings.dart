import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/src/state/json_store.dart';
import 'package:open_chess/src/state/player_profile.dart';
import 'package:open_chess/src/state/profile_avatar_service.dart';

/// A board colour scheme.
class BoardThemeOption {
  final String name;
  final Color light;
  final Color dark;
  const BoardThemeOption(this.name, this.light, this.dark);
}

const boardThemes = <BoardThemeOption>[
  BoardThemeOption('Green', Color(0xFFEEEED2), Color(0xFF769656)),
  BoardThemeOption('Brown', Color(0xFFF0D9B5), Color(0xFFB58863)),
  BoardThemeOption('Blue', Color(0xFFDEE3E6), Color(0xFF8CA2AD)),
  BoardThemeOption('Gray', Color(0xFFDCDCDC), Color(0xFF909090)),
];

class Settings {
  final int boardTheme; // index into boardThemes
  final bool soundOn;
  final bool showHints;
  final int animationMs;
  final bool haptics;
  final String defaultTc; // time-control preset label
  final String defaultDifficulty; // difficulty preset name
  final String themeMode; // 'system' | 'light' | 'dark'
  final bool highContrast; // accessibility: stark board colours
  final bool colorblind; // accessibility: colourblind-safe move-quality palette
  final double textScale; // 1.0 = follow OS; >1 enlarges text
  final String? localeCode; // null = follow system; else 'en','tr',…
  final PlayerProfile playerProfile;
  final bool checkUpdatesOnLaunch; // one GitHub request at startup

  const Settings({
    this.boardTheme = 0,
    this.soundOn = true,
    this.showHints = true,
    this.animationMs = 150,
    this.haptics = true,
    this.defaultTc = 'Infinite',
    this.defaultDifficulty = 'Normal',
    this.themeMode = 'dark',
    this.highContrast = false,
    this.colorblind = false,
    this.textScale = 1.0,
    this.localeCode,
    this.playerProfile = const PlayerProfile(),
    this.checkUpdatesOnLaunch = true,
  });

  BoardThemeOption get theme {
    if (highContrast) {
      return const BoardThemeOption(
        'High contrast',
        Color(0xFFFFFFFF),
        Color(0xFF1A1A1A),
      );
    }
    return boardThemes[boardTheme.clamp(0, boardThemes.length - 1)];
  }

  ThemeMode get materialThemeMode => switch (themeMode) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Settings copyWith({
    int? boardTheme,
    bool? soundOn,
    bool? showHints,
    int? animationMs,
    bool? haptics,
    String? defaultTc,
    String? defaultDifficulty,
    String? themeMode,
    bool? highContrast,
    bool? colorblind,
    double? textScale,
    String? localeCode,
    PlayerProfile? playerProfile,
    bool? checkUpdatesOnLaunch,
    bool clearLocale = false,
  }) => Settings(
    boardTheme: boardTheme ?? this.boardTheme,
    soundOn: soundOn ?? this.soundOn,
    showHints: showHints ?? this.showHints,
    animationMs: animationMs ?? this.animationMs,
    haptics: haptics ?? this.haptics,
    defaultTc: defaultTc ?? this.defaultTc,
    defaultDifficulty: defaultDifficulty ?? this.defaultDifficulty,
    themeMode: themeMode ?? this.themeMode,
    highContrast: highContrast ?? this.highContrast,
    colorblind: colorblind ?? this.colorblind,
    textScale: textScale ?? this.textScale,
    localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
    playerProfile: playerProfile ?? this.playerProfile,
    checkUpdatesOnLaunch: checkUpdatesOnLaunch ?? this.checkUpdatesOnLaunch,
  );

  Map<String, dynamic> toJson() => {
    'boardTheme': boardTheme,
    'soundOn': soundOn,
    'showHints': showHints,
    'animationMs': animationMs,
    'haptics': haptics,
    'defaultTc': defaultTc,
    'defaultDifficulty': defaultDifficulty,
    'themeMode': themeMode,
    'highContrast': highContrast,
    'colorblind': colorblind,
    'textScale': textScale,
    'localeCode': localeCode,
    'playerProfile': playerProfile.toJson(),
    'checkUpdatesOnLaunch': checkUpdatesOnLaunch,
  };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
    boardTheme: j['boardTheme'] as int? ?? 0,
    soundOn: j['soundOn'] as bool? ?? true,
    showHints: j['showHints'] as bool? ?? true,
    animationMs: j['animationMs'] as int? ?? 150,
    haptics: j['haptics'] as bool? ?? true,
    defaultTc: j['defaultTc'] as String? ?? 'Infinite',
    defaultDifficulty: _migrateDifficulty(
      j['defaultDifficulty'] as String? ?? 'Normal',
    ),
    themeMode: j['themeMode'] as String? ?? 'dark',
    highContrast: j['highContrast'] as bool? ?? false,
    colorblind: j['colorblind'] as bool? ?? false,
    textScale: (j['textScale'] as num?)?.toDouble() ?? 1.0,
    localeCode: j['localeCode'] as String?,
    // Older settings files simply omit profile data. Also accept the
    // temporary flat shape so no local identity is lost during migration.
    playerProfile: _profileFromJson(j),
    checkUpdatesOnLaunch: j['checkUpdatesOnLaunch'] as bool? ?? true,
  );

  static PlayerProfile _profileFromJson(Map<String, dynamic> json) {
    final profile = PlayerProfile.fromJson(
      json['playerProfile'] ??
          {
            'username': json['username'],
            'avatarBase64': json['avatarBase64'] ?? json['avatar'],
          },
    );
    final avatar = profile.avatarBytes;
    if (avatar == null) return profile;
    try {
      return profile.copyWith(avatarBytes: normalizeProfileAvatar(avatar));
    } catch (_) {
      return profile.copyWith(clearAvatar: true);
    }
  }

  static String _migrateDifficulty(String value) => switch (value) {
    'Beginner' => 'Very Easy',
    'Medium' => 'Normal',
    'Expert' => 'Very Hard',
    _ => value,
  };
}

final settingsStore = JsonStore<Settings>(
  'settings.json',
  decode: (j) => Settings.fromJson(j as Map<String, dynamic>),
  encode: (s) => s.toJson(),
  empty: const Settings(),
);

/// Settings loaded from disk before `runApp`, so the first frame (and any
/// one-shot reads in setup screens) sees the persisted values, not defaults.
Settings _bootSettings = const Settings();

/// Call once in `main()` before `runApp`.
Future<void> preloadSettings() async {
  try {
    _bootSettings = await settingsStore.load();
  } catch (_) {
    // Unreadable and could not be backed up: run on defaults; the store keeps
    // refusing to write so the original file is not lost.
  }
}

final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);

class SettingsController extends Notifier<Settings> {
  @override
  Settings build() => _bootSettings;

  void _update(Settings s) {
    state = s;
    // Serialized + atomic; a failure keeps the old file and is reported once.
    settingsStore
        .set(s)
        .then<void>(
          (_) {},
          onError: (_) {
            storeWriteFailures.value++;
          },
        );
  }

  void setBoardTheme(int i) => _update(state.copyWith(boardTheme: i));
  void setSound(bool v) => _update(state.copyWith(soundOn: v));
  void setHints(bool v) => _update(state.copyWith(showHints: v));
  void setAnimationMs(int v) => _update(state.copyWith(animationMs: v));
  void setHaptics(bool v) => _update(state.copyWith(haptics: v));
  void setDefaultTc(String v) => _update(state.copyWith(defaultTc: v));
  void setDefaultDifficulty(String v) =>
      _update(state.copyWith(defaultDifficulty: v));
  void setThemeMode(String v) => _update(state.copyWith(themeMode: v));
  void setHighContrast(bool v) => _update(state.copyWith(highContrast: v));
  void setColorblind(bool v) => _update(state.copyWith(colorblind: v));
  void setCheckUpdatesOnLaunch(bool v) =>
      _update(state.copyWith(checkUpdatesOnLaunch: v));
  void setTextScale(double v) => _update(state.copyWith(textScale: v));
  void setLocale(String? code) => _update(
    code == null
        ? state.copyWith(clearLocale: true)
        : state.copyWith(localeCode: code),
  );
  void setUsername(String value) => _update(
    state.copyWith(
      playerProfile: state.playerProfile.copyWith(username: value),
    ),
  );
  void setAvatar(Uint8List? value) => _update(
    state.copyWith(
      playerProfile: _normalizedProfile(
        username: state.playerProfile.username,
        avatarBytes: value,
      ),
    ),
  );
  void setPlayerProfile(PlayerProfile value) => _update(
    state.copyWith(
      playerProfile: _normalizedProfile(
        username: value.username,
        avatarBytes: value.avatarBytes,
      ),
    ),
  );

  PlayerProfile _normalizedProfile({
    required String username,
    required Uint8List? avatarBytes,
  }) => PlayerProfile.normalized(
    username: username,
    avatarBytes: avatarBytes == null
        ? null
        : normalizeProfileAvatar(avatarBytes),
  );
}

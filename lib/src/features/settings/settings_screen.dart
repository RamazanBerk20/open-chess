import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/l10n/app_localizations.dart';
import 'package:open_chess/src/state/difficulty.dart';
import 'package:open_chess/src/state/l10n_labels.dart';
import 'package:open_chess/src/state/player_profile.dart';
import 'package:open_chess/src/state/profile_avatar_service.dart';
import 'package:open_chess/src/state/settings.dart';
import 'package:open_chess/src/state/time_control.dart';
import 'package:open_chess/src/state/update_service.dart';
import 'package:open_chess/src/widgets/player_avatar.dart';
import 'package:open_chess/src/widgets/update_dialog.dart';

/// Locale code → native display name (null = follow the system).
const _localeNames = <String?, String>{
  null: '',
  'en': 'English',
  'tr': 'Türkçe',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'ru': 'Русский',
  'ar': 'العربية',
  'ja': '日本語',
  'zh': '中文',
  'ko': '한국어',
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListView(
        children: [
          _Header(t.profile),
          _ProfileSettingsTile(profile: s.playerProfile, controller: c),
          _Header(t.appearance),
          ListTile(
            title: Text(t.theme),
            trailing: DropdownButton<String>(
              value: s.themeMode,
              onChanged: (v) => v != null ? c.setThemeMode(v) : null,
              items: [
                DropdownMenuItem(value: 'system', child: Text(t.themeSystem)),
                DropdownMenuItem(value: 'light', child: Text(t.themeLight)),
                DropdownMenuItem(value: 'dark', child: Text(t.themeDark)),
              ],
            ),
          ),
          ListTile(
            title: Text(t.boardThemeLabel),
            trailing: DropdownButton<int>(
              value: s.boardTheme,
              onChanged: s.highContrast
                  ? null
                  : (v) => v != null ? c.setBoardTheme(v) : null,
              items: [
                for (int i = 0; i < boardThemes.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(localizedBoardTheme(t, boardThemes[i].name)),
                  ),
              ],
            ),
          ),
          _Header(t.language),
          ListTile(
            title: Text(t.language),
            trailing: DropdownButton<String?>(
              value: s.localeCode,
              onChanged: c.setLocale,
              items: [
                for (final entry in _localeNames.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(
                      entry.key == null ? t.languageSystem : entry.value,
                    ),
                  ),
              ],
            ),
          ),
          _Header(t.accessibility),
          SwitchListTile(
            title: Text(t.highContrast),
            value: s.highContrast,
            onChanged: c.setHighContrast,
          ),
          SwitchListTile(
            title: Text(t.colorblindSafe),
            value: s.colorblind,
            onChanged: c.setColorblind,
          ),
          ListTile(
            title: Text(t.textSize),
            subtitle: Slider(
              value: s.textScale,
              min: 0.8,
              max: 1.6,
              divisions: 8,
              label: '${(s.textScale * 100).round()}%',
              onChanged: c.setTextScale,
            ),
          ),
          _Header(t.gameplay),
          SwitchListTile(
            title: Text(t.moveHints),
            value: s.showHints,
            onChanged: c.setHints,
          ),
          SwitchListTile(
            title: Text(t.sound),
            value: s.soundOn,
            onChanged: c.setSound,
          ),
          SwitchListTile(
            title: Text(t.haptics),
            value: s.haptics,
            onChanged: c.setHaptics,
          ),
          ListTile(
            title: Text(t.animationSpeed),
            subtitle: Slider(
              value: s.animationMs.toDouble(),
              min: 0,
              max: 400,
              divisions: 8,
              label: s.animationMs == 0
                  ? t.animationOff
                  : t.animationMs(s.animationMs),
              onChanged: (v) => c.setAnimationMs(v.round()),
            ),
          ),
          _Header(t.defaultTimeControl),
          ListTile(
            title: Text(t.defaultTimeControl),
            trailing: DropdownButton<String>(
              value: s.defaultTc,
              onChanged: (v) => v != null ? c.setDefaultTc(v) : null,
              items: [
                for (final p in TimeControlOption.presets)
                  DropdownMenuItem(
                    value: p.label,
                    child: Text(localizedTc(t, p.label)),
                  ),
              ],
            ),
          ),
          ListTile(
            title: Text(t.defaultDifficulty),
            trailing: DropdownButton<String>(
              value: s.defaultDifficulty,
              onChanged: (v) => v != null ? c.setDefaultDifficulty(v) : null,
              items: [
                for (final d in Difficulty.presets)
                  DropdownMenuItem(
                    value: d.name,
                    child: Text(localizedDifficulty(t, d.name)),
                  ),
              ],
            ),
          ),
          _Header(t.support),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: Text(t.donate),
            subtitle: Text(t.donateSubtitle),
            onTap: () => openUrlOrReport(context, sponsorUrl),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: Text(t.checkForUpdates),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(t.checkingForUpdates),
                  duration: const Duration(seconds: 1),
                ),
              );
              final info = await checkForUpdate();
              if (!context.mounted) return;
              await showUpdateResult(context, info);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.update),
            title: Text(t.checkUpdatesOnLaunch),
            value: s.checkUpdatesOnLaunch,
            onChanged: c.setCheckUpdatesOnLaunch,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(t.about),
            subtitle: FutureBuilder<String>(
              future: currentVersion(),
              builder: (_, snap) => Text(snap.hasData ? 'v${snap.data}' : ''),
            ),
            onTap: () => openUrlOrReport(context, repoUrl),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ProfileSettingsTile extends StatelessWidget {
  final PlayerProfile profile;
  final SettingsController controller;

  const _ProfileSettingsTile({required this.profile, required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ListTile(
      leading: PlayerAvatar(profile: profile),
      title: Text(t.profileUsername),
      subtitle: Text(
        profile.username,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _ProfileEditorDialog(
          initialProfile: profile,
          controller: controller,
        ),
      ),
    );
  }
}

class _ProfileEditorDialog extends StatefulWidget {
  final PlayerProfile initialProfile;
  final SettingsController controller;

  const _ProfileEditorDialog({
    required this.initialProfile,
    required this.controller,
  });

  @override
  State<_ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<_ProfileEditorDialog> {
  late final TextEditingController _usernameController;
  late PlayerProfile _draft;
  var _selectingAvatar = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialProfile;
    _usernameController = TextEditingController(text: _draft.username);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _selectAvatar() async {
    if (_selectingAvatar) return;
    setState(() => _selectingAvatar = true);
    try {
      final avatar = await pickProfileAvatar();
      if (!mounted || avatar == null) return;
      setState(() => _draft = _draft.copyWith(avatarBytes: avatar));
    } on ProfileAvatarException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).profileImageError)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).profileImageError)),
      );
    } finally {
      if (mounted) setState(() => _selectingAvatar = false);
    }
  }

  void _removeAvatar() {
    setState(() => _draft = _draft.copyWith(clearAvatar: true));
  }

  void _save() {
    widget.controller.setPlayerProfile(
      _draft.copyWith(username: _usernameController.text),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.profile),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  PlayerAvatar(profile: _draft, radius: 34),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      t.profileAvatar,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: t.profileChangeAvatar,
                    onPressed: _selectingAvatar ? null : _selectAvatar,
                    icon: _selectingAvatar
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_library_outlined),
                  ),
                  if (_draft.hasCustomAvatar)
                    IconButton(
                      tooltip: t.profileRemoveAvatar,
                      onPressed: _removeAvatar,
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _usernameController,
                maxLength: PlayerProfile.maxUsernameLength,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: t.profileUsername,
                  hintText: t.profileUsernameHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(t.save)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

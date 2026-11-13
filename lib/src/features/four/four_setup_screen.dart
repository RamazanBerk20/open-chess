import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/l10n/app_localizations.dart';
import 'package:open_chess/src/features/four/four_lobby_screen.dart';
import 'package:open_chess/src/features/four/four_player_screen.dart';
import 'package:open_chess/src/rust/api/four.dart';
import 'package:open_chess/src/rust/api/net.dart';
import 'package:open_chess/src/state/difficulty.dart';
import 'package:open_chess/src/state/four_lan_controller.dart';
import 'package:open_chess/src/state/four_player_controller.dart';
import 'package:open_chess/src/state/l10n_labels.dart';
import 'package:open_chess/src/state/multicast_lock.dart';
import 'package:open_chess/src/state/settings.dart';
import 'package:open_chess/src/widgets/player_avatar.dart';

class FourSetupScreen extends ConsumerStatefulWidget {
  const FourSetupScreen({super.key});

  @override
  ConsumerState<FourSetupScreen> createState() => _FourSetupScreenState();
}

class _FourSetupScreenState extends ConsumerState<FourSetupScreen> {
  FourFormat _format = FourFormat.freeForAll;
  FourMode _mode = FourMode.vsBots;
  FourPlayer _seat = FourPlayer.red;
  int _aiDifficultyCode = defaultFourAiDifficultyCode;
  bool _allowSpectators = false;
  final List<NetHost> _hosts = [];
  StreamSubscription<NetHost>? _browse;

  @override
  void dispose() {
    if (_browse != null) releaseMulticast();
    _browse?.cancel();
    netStopBrowse();
    super.dispose();
  }

  void _startBrowse() {
    if (_browse != null) return;
    _hosts.clear();
    acquireMulticast();
    _browse = netBrowse().listen((h) {
      if (h.mode != 'four_player') return;
      if (!mounted) return;
      setState(() {
        final index = _hosts.indexWhere((existing) => existing.addr == h.addr);
        if (index < 0) {
          _hosts.add(h);
        } else {
          _hosts[index] = h;
        }
      });
    });
  }

  void _stopBrowse() {
    if (_browse != null) releaseMulticast();
    _browse?.cancel();
    _browse = null;
    netStopBrowse();
    _hosts.clear();
  }

  String get _formatCode => _format == FourFormat.teams ? 'teams' : 'ffa';

  void _startLocal() {
    final config = FourConfig(
      mode: _mode,
      format: _format,
      humanSeats: {_seat},
      aiDifficultyCode: _aiDifficultyCode,
    );
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => FourPlayerScreen(config: config)));
  }

  void _hostLan() {
    ref
        .read(fourLanProvider.notifier)
        .host(
          ref.read(settingsProvider).playerProfile,
          _formatCode,
          allowSpectators: _allowSpectators,
        );
    _stopBrowse();
    // Back from the lobby: browse again so the host list is live.
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FourLobbyScreen()))
        .then((_) {
          if (mounted && _mode == FourMode.lan) _startBrowse();
        });
  }

  void _joinLan(NetHost h) {
    ref
        .read(fourLanProvider.notifier)
        .join(h.addr, ref.read(settingsProvider).playerProfile);
    _stopBrowse();
    // Back from the lobby: browse again so the host list is live.
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FourLobbyScreen()))
        .then((_) {
          if (mounted && _mode == FourMode.lan) _startBrowse();
        });
  }

  void _spectateLan(NetHost h) {
    ref
        .read(fourLanProvider.notifier)
        .spectate(h.addr, ref.read(settingsProvider).playerProfile);
    _stopBrowse();
    // Back from the lobby: browse again so the host list is live.
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FourLobbyScreen()))
        .then((_) {
          if (mounted && _mode == FourMode.lan) _startBrowse();
        });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final profile = ref.watch(settingsProvider).playerProfile;
    Widget heading(String s) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(s, style: Theme.of(context).textTheme.titleMedium),
    );

    return Scaffold(
      appBar: AppBar(title: Text(t.menuFourPlayer)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          heading(t.fourFormat),
          SegmentedButton<FourFormat>(
            segments: [
              ButtonSegment(
                value: FourFormat.freeForAll,
                label: Text(t.fourFFA),
              ),
              ButtonSegment(value: FourFormat.teams, label: Text(t.fourTeams)),
            ],
            selected: {_format},
            onSelectionChanged: (s) => setState(() => _format = s.first),
          ),
          heading(t.bugMode),
          SegmentedButton<FourMode>(
            segments: [
              ButtonSegment(value: FourMode.vsBots, label: Text(t.fourVsBots)),
              ButtonSegment(value: FourMode.lan, label: Text(t.bugLan)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) {
              setState(() => _mode = s.first);
              if (_mode == FourMode.lan) {
                _startBrowse();
              } else {
                _stopBrowse();
              }
            },
          ),
          if (_mode == FourMode.vsBots) ...[
            heading(t.fourYourSeats),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in FourPlayer.values)
                  ChoiceChip(
                    label: Text(localizedFourColor(t, p)),
                    selected: _seat == p,
                    onSelected: (_) => setState(() => _seat = p),
                  ),
              ],
            ),
            heading(t.difficulty),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 240,
                child: DropdownButtonFormField<int>(
                  initialValue: _aiDifficultyCode,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    for (var code = 0; code < Difficulty.presets.length; code++)
                      DropdownMenuItem(
                        value: code,
                        child: Text(
                          localizedDifficulty(t, Difficulty.presets[code].name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _aiDifficultyCode = value);
                    }
                  },
                ),
              ),
            ),
          ],
          if (_mode == FourMode.lan) ...[
            heading(t.yourName),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PlayerAvatar(profile: profile, radius: 20),
              title: Text(profile.username),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(t.lanAllowSpectators),
              value: _allowSpectators,
              onChanged: (value) => setState(() => _allowSpectators = value),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                icon: const Icon(Icons.wifi_tethering),
                label: Text(t.bugHostMatch),
                onPressed: _hostLan,
              ),
            ),
            const SizedBox(height: 8),
            Text(t.bugJoinMatch, style: Theme.of(context).textTheme.titleSmall),
            if (_hosts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            for (final h in _hosts)
              ListTile(
                leading: const Icon(Icons.grid_4x4),
                title: Text(h.name),
                subtitle: Text(
                  '${h.variant == 'teams' ? t.fourTeams : t.fourFFA}  ·  ${h.timeControl}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PlayerCount(host: h),
                    if (h.spectatorsEnabled)
                      IconButton(
                        tooltip: t.lanSpectate,
                        icon: const Icon(Icons.visibility_outlined),
                        onPressed: () => _spectateLan(h),
                      ),
                  ],
                ),
                onTap: h.playerCount < h.maxPlayers
                    ? () => _joinLan(h)
                    : h.spectatorsEnabled
                    ? () => _spectateLan(h)
                    : null,
              ),
          ] else if (_mode == FourMode.vsBots) ...[
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text(t.bugStart),
                onPressed: _startLocal,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerCount extends StatelessWidget {
  final NetHost host;
  const _PlayerCount({required this.host});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.people_outline, size: 18),
      const SizedBox(width: 4),
      Text('${host.playerCount}/${host.maxPlayers}'),
    ],
  );
}

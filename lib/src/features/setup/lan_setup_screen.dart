import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/l10n/app_localizations.dart';
import 'package:open_chess/src/features/game/game_screen.dart';
import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/rust/api/net.dart';
import 'package:open_chess/src/state/l10n_labels.dart';
import 'package:open_chess/src/state/multicast_lock.dart';
import 'package:open_chess/src/state/lan_controller.dart';
import 'package:open_chess/src/state/settings.dart';
import 'package:open_chess/src/state/time_control.dart';
import 'package:open_chess/src/widgets/player_avatar.dart';

enum _HostColor { white, black, random }

class LanSetupScreen extends ConsumerStatefulWidget {
  const LanSetupScreen({super.key});

  @override
  ConsumerState<LanSetupScreen> createState() => _LanSetupScreenState();
}

class _LanSetupScreenState extends ConsumerState<LanSetupScreen> {
  late final LanController _lan;
  TimeControlOption _tc = const TimeControlOption('5+2', 5, 2);
  _HostColor _color = _HostColor.random; // host's chosen colour
  GameVariant _variant = GameVariant.standard;
  bool _allowSpectators = false;
  bool _enteredGame = false;
  bool _sessionStarted = false;
  final Map<String, NetHost> _hosts = {};
  StreamSubscription<NetHost>? _browseSub;

  @override
  void initState() {
    super.initState();
    _lan = ref.read(lanProvider.notifier);
    acquireMulticast(); // browsing, and answering discovery while hosting
    _browseSub = netBrowse().listen((h) {
      if (!mounted) return;
      if (h.mode != 'two_player') return;
      setState(() => _hosts[h.addr] = h);
    });
  }

  @override
  void dispose() {
    _browseSub?.cancel();
    netStopBrowse();
    releaseMulticast();
    if (!_enteredGame && _sessionStarted) {
      _lan.leave();
    }
    super.dispose();
  }

  String _colorLabel(AppLocalizations t, _HostColor c) => switch (c) {
    _HostColor.white => t.colourWhite,
    _HostColor.black => t.colourBlack,
    _HostColor.random => t.colourRandom,
  };

  String _hostModeLabel(AppLocalizations t, NetHost host) {
    final variant = variantFromCode(host.variant);
    final mode = switch (host.mode) {
      'two_player' => t.menuTwoPlayers,
      'bughouse' => t.menuBughouse,
      'four_player' => t.menuFourPlayer,
      _ => t.lanTitle,
    };
    return '$mode · ${localizedVariant(t, variant)}';
  }

  void _cancelLan() {
    _lan.leave();
    _sessionStarted = false;
  }

  @override
  Widget build(BuildContext context) {
    // Navigate into the game once connected.
    ref.listen<LanGameState>(lanProvider, (prev, next) {
      if (next.connected && (prev == null || !prev.connected)) {
        _enteredGame = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GameScreen()),
        );
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizeLanError(AppLocalizations.of(context), next.error!),
            ),
          ),
        );
      }
    });

    final lan = ref.watch(lanProvider);
    final profile = ref.watch(settingsProvider).playerProfile;
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.lanTitle)),
      body: lan.waiting
          ? _Waiting(onCancel: _cancelLan)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: PlayerAvatar(profile: profile, radius: 20),
                  title: Text(profile.username),
                ),
                const SizedBox(height: 24),
                Text(
                  t.hostAGame,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in TimeControlOption.presets)
                      ChoiceChip(
                        label: Text(localizedTc(t, p.label)),
                        selected: _tc.label == p.label,
                        onSelected: (_) => setState(() => _tc = p),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(t.variant, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in lanVariants)
                      ChoiceChip(
                        label: Text(localizedVariant(t, v)),
                        selected: _variant == v,
                        onSelected: (_) => setState(() {
                          _variant = v;
                          if (v == GameVariant.fogOfWar) {
                            _allowSpectators = false;
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  t.yourColour,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in _HostColor.values)
                      ChoiceChip(
                        label: Text(_colorLabel(t, c)),
                        selected: _color == c,
                        onSelected: (_) => setState(() => _color = c),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.lanAllowSpectators),
                  value: _allowSpectators && _variant != GameVariant.fogOfWar,
                  onChanged: _variant == GameVariant.fogOfWar
                      ? null
                      : (value) => setState(() => _allowSpectators = value),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.wifi_tethering),
                    label: Text(t.hostGame),
                    onPressed: () {
                      final hostWhite = switch (_color) {
                        _HostColor.white => true,
                        _HostColor.black => false,
                        _HostColor.random => Random().nextBool(),
                      };
                      _sessionStarted = true;
                      _lan.host(
                        profile,
                        _tc.baseMinutes ?? 0,
                        _tc.incrementSeconds,
                        hostWhite,
                        _variant,
                        _variant == GameVariant.chess960
                            ? Random().nextInt(960)
                            : 0,
                        _allowSpectators,
                      );
                    },
                  ),
                ),
                const Divider(height: 40),
                Text(
                  t.joinOnNetwork,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_hosts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(t.searchingHosts),
                      ],
                    ),
                  ),
                for (final h in _hosts.values) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.computer),
                      title: Text(h.name),
                      subtitle: Text(
                        '${_hostModeLabel(t, h)}  ·  ${h.timeControl}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text('${h.playerCount}/${h.maxPlayers}'),
                          const SizedBox(width: 4),
                          if (h.spectatorsEnabled)
                            IconButton(
                              tooltip: t.lanSpectate,
                              icon: const Icon(Icons.visibility_outlined),
                              onPressed: () {
                                _sessionStarted = true;
                                _lan.spectate(h.addr, profile);
                              },
                            ),
                          Icon(
                            Icons.login,
                            color: h.playerCount >= h.maxPlayers
                                ? Theme.of(context).colorScheme.outline
                                : null,
                          ),
                        ],
                      ),
                      onTap: h.playerCount >= h.maxPlayers
                          ? null
                          : () {
                              _sessionStarted = true;
                              _lan.join(h.addr, profile);
                            },
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _Waiting extends StatelessWidget {
  final VoidCallback onCancel;
  const _Waiting({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(t.waitingOpponent),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onCancel, child: Text(t.cancel)),
        ],
      ),
    );
  }
}

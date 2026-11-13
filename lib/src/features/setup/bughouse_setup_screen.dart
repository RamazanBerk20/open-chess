import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/l10n/app_localizations.dart';
import 'package:open_chess/src/features/bughouse/bughouse_lobby_screen.dart';
import 'package:open_chess/src/rust/api/net.dart';
import 'package:open_chess/src/state/bughouse_lan_controller.dart';
import 'package:open_chess/src/state/multicast_lock.dart';
import 'package:open_chess/src/state/settings.dart';
import 'package:open_chess/src/widgets/player_avatar.dart';

/// Bughouse needs four independently controlled seats, so it is available only
/// as a LAN match. The lobby assigns one seat to each connected device.
class BughouseSetupScreen extends ConsumerStatefulWidget {
  const BughouseSetupScreen({super.key});

  @override
  ConsumerState<BughouseSetupScreen> createState() =>
      _BughouseSetupScreenState();
}

class _BughouseSetupScreenState extends ConsumerState<BughouseSetupScreen> {
  final List<NetHost> _hosts = [];
  StreamSubscription<NetHost>? _browse;

  @override
  void initState() {
    super.initState();
    _startBrowse();
  }

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
      if (h.mode != 'bughouse') return;
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

  void _hostLan() {
    ref
        .read(bughouseLanProvider.notifier)
        .host(ref.read(settingsProvider).playerProfile);
    _stopBrowse();
    // Back from the lobby: browse again so the host list is live.
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const BughouseLobbyScreen()))
        .then((_) {
          if (mounted) _startBrowse();
        });
  }

  void _joinLan(NetHost host) {
    ref
        .read(bughouseLanProvider.notifier)
        .join(host.addr, ref.read(settingsProvider).playerProfile);
    _stopBrowse();
    // Back from the lobby: browse again so the host list is live.
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const BughouseLobbyScreen()))
        .then((_) {
          if (mounted) _startBrowse();
        });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final profile = ref.watch(settingsProvider).playerProfile;
    return Scaffold(
      appBar: AppBar(title: Text(t.menuBughouse)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: PlayerAvatar(profile: profile, radius: 20),
            title: Text(profile.username),
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
          const SizedBox(height: 24),
          Text(t.bugJoinMatch, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_hosts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
          for (final host in _hosts)
            ListTile(
              leading: const Icon(Icons.casino),
              title: Text(host.name),
              subtitle: Text('${t.menuBughouse}  ·  ${host.timeControl}'),
              trailing: _PlayerCount(host: host),
              onTap: host.playerCount >= host.maxPlayers
                  ? null
                  : () => _joinLan(host),
            ),
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

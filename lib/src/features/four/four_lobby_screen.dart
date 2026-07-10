import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/l10n/app_localizations.dart';
import 'package:open_chess/src/features/four/four_player_screen.dart';
import 'package:open_chess/src/rust/api/four.dart';
import 'package:open_chess/src/rust/api/net.dart';
import 'package:open_chess/src/state/difficulty.dart';
import 'package:open_chess/src/state/four_lan_controller.dart';
import 'package:open_chess/src/state/four_player_controller.dart';
import 'package:open_chess/src/state/l10n_labels.dart';

/// Pre-match lobby for networked 4-player: the host assigns the four seats and
/// starts; joiners wait. On start, both push into [FourPlayerScreen] (LAN).
class FourLobbyScreen extends ConsumerStatefulWidget {
  const FourLobbyScreen({super.key});

  @override
  ConsumerState<FourLobbyScreen> createState() => _FourLobbyScreenState();
}

class _FourLobbyScreenState extends ConsumerState<FourLobbyScreen> {
  late final FourLanController _lan;
  final List<int> _owner = [
    fourLanHostSeatOwner,
    fourLanAiSeatOwner,
    fourLanAiSeatOwner,
    fourLanAiSeatOwner,
  ]; // seat owner: connection index, host, or host-run AI
  final List<int> _aiDifficulty = [
    fourLanNoAiDifficulty,
    fourLanDefaultAiDifficulty,
    fourLanDefaultAiDifficulty,
    fourLanDefaultAiDifficulty,
  ];
  bool _navigated = false;
  bool _navigationScheduled = false;

  @override
  void initState() {
    super.initState();
    _lan = ref.read(fourLanProvider.notifier);
  }

  @override
  void dispose() {
    if (!_navigated) _lan.leave();
    super.dispose();
  }

  void _goToMatch(FourLanState s) {
    if (_navigated || _navigationScheduled) return;
    _navigationScheduled = true;
    final mySeats = s.mySeats.map((i) => FourPlayer.values[i]).toSet();
    final config = FourConfig(
      mode: FourMode.lan,
      format: s.format == 'teams' ? FourFormat.teams : FourFormat.freeForAll,
      humanSeats: mySeats,
      lanSend: s.isSpectator
          ? null
          : (seat, uci) => netSendFourMove(seat: seat, uci: uci),
      isSpectator: s.isSpectator,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigated = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => FourPlayerScreen(config: config)),
      );
    });
  }

  void _setSeatOwner(int seat, int? owner) {
    final nextOwner = owner ?? fourLanAiSeatOwner;
    setState(() {
      final wasAi = _owner[seat] == fourLanAiSeatOwner;
      _owner[seat] = nextOwner;
      if (nextOwner != fourLanAiSeatOwner) {
        _aiDifficulty[seat] = fourLanNoAiDifficulty;
      } else if (!wasAi ||
          _aiDifficulty[seat] < 0 ||
          _aiDifficulty[seat] >= fourLanAiDifficultyCount) {
        _aiDifficulty[seat] = fourLanDefaultAiDifficulty;
      }
    });
  }

  void _randomizeSeatColors(int joinerCount) {
    final currentIsComplete =
        isValidFourLanSeatAssignment(_owner, joinerCount) &&
        isValidFourLanAiDifficulties(_owner, _aiDifficulty);
    final source = currentIsComplete
        ? FourLanSeatAssignment(
            seatOwners: _owner,
            aiDifficulties: _aiDifficulty,
          )
        : defaultFourLanSeatAssignment(joinerCount);
    final assignment = randomizeFourLanSeatAssignment(
      source.seatOwners,
      source.aiDifficulties,
      joinerCount: joinerCount,
    );
    setState(() {
      _owner.setAll(0, assignment.seatOwners);
      _aiDifficulty.setAll(0, assignment.aiDifficulties);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = ref.watch(fourLanProvider);
    if (s.started) _goToMatch(s);

    final seatLabels = [t.fourRed, t.fourBlue, t.fourYellow, t.fourGreen];
    final ownerOptions = <(int, String)>[
      (fourLanHostSeatOwner, t.bugSeatHost),
      (fourLanAiSeatOwner, t.fourSeatAi),
      for (var index = 0; index < s.joiners.length; index++)
        (index, s.joiners[index]),
    ];
    final ownerDropdownWidth = (MediaQuery.sizeOf(context).width * 0.42)
        .clamp(128.0, 220.0)
        .toDouble();
    Widget ownerLabel(String label) => SizedBox(
      width: ownerDropdownWidth - 24,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    final canStart =
        isValidFourLanSeatAssignment(_owner, s.joiners.length) &&
        isValidFourLanAiDifficulties(_owner, _aiDifficulty);

    return Scaffold(
      appBar: AppBar(title: Text(t.menuFourPlayer)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (s.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(s.error!, style: const TextStyle(color: Colors.red)),
            ),
          if (!s.isHost) ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Center(child: Text(t.bugWaitingHost)),
          ] else ...[
            Text(
              '${t.bugPlayersJoined}: ${s.joiners.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              t.bugAssignSeats,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.shuffle),
                label: Text(t.colourRandom),
                onPressed: () => _randomizeSeatColors(s.joiners.length),
              ),
            ),
            const SizedBox(height: 4),
            for (var seat = 0; seat < 4; seat++) ...[
              ListTile(
                dense: true,
                title: Text(seatLabels[seat]),
                trailing: SizedBox(
                  width: ownerDropdownWidth,
                  child: DropdownButton<int>(
                    value: _owner[seat],
                    isExpanded: true,
                    items: [
                      for (final option in ownerOptions)
                        DropdownMenuItem(
                          value: option.$1,
                          child: ownerLabel(option.$2),
                        ),
                    ],
                    selectedItemBuilder: (_) => [
                      for (final option in ownerOptions)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ownerLabel(option.$2),
                        ),
                    ],
                    onChanged: (value) => _setSeatOwner(seat, value),
                  ),
                ),
              ),
              if (_owner[seat] == fourLanAiSeatOwner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Text(t.difficulty),
                      const Spacer(),
                      DropdownButton<int>(
                        value: _aiDifficulty[seat],
                        isDense: true,
                        items: [
                          for (
                            var code = 0;
                            code < Difficulty.presets.length;
                            code++
                          )
                            DropdownMenuItem(
                              value: code,
                              child: Text(
                                localizedDifficulty(
                                  t,
                                  Difficulty.presets[code].name,
                                ),
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _aiDifficulty[seat] = value);
                        },
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text(t.bugStart),
                onPressed: canStart
                    ? () => ref
                          .read(fourLanProvider.notifier)
                          .startAssign(_owner, _aiDifficulty)
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/l10n/app_localizations.dart';
import 'package:open_chess/src/features/game/game_screen.dart';
import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/state/difficulty.dart';
import 'package:open_chess/src/state/game_mode.dart';
import 'package:open_chess/src/state/game_providers.dart';
import 'package:open_chess/src/state/lan_controller.dart';
import 'package:open_chess/src/state/l10n_labels.dart';
import 'package:open_chess/src/state/saved_games.dart';
import 'package:open_chess/src/state/time_control.dart';

class ResumeScreen extends ConsumerWidget {
  const ResumeScreen({super.key});

  void _resume(WidgetRef ref, BuildContext context, SavedGame g) {
    // Resumed games are reviewed/continued as same-device 2P while preserving
    // their original position, rules, and configured clock.
    final tc = g.baseMinutes == null
        ? TimeControlOption.infinite
        : TimeControlOption(
            '${g.baseMinutes}+${g.incrementSeconds}',
            g.baseMinutes,
            g.incrementSeconds,
          );
    final variant = variantFromCode(g.variantCode);
    // A saved local continuation cannot preserve the separate private views or
    // four-seat topology required by these network-only variants.
    if (onlineOnlyVariants.contains(variant) ||
        (!g.vsAi && !sameDeviceVariants.contains(variant))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).savedCorrupt)),
      );
      return;
    }
    if (hasActiveLanSession(ref.read(lanProvider))) {
      ref.read(lanProvider.notifier).leave();
    }
    ref.read(selectedTimeControlProvider.notifier).set(tc);
    if (g.vsAi) {
      final difficulty = Difficulty.presets.firstWhere(
        (level) => level.name == g.difficultyName,
        orElse: () => Difficulty.normal,
      );
      final aiColor = g.aiColorCode == 'white'
          ? PieceColor.white
          : PieceColor.black;
      ref.read(gameModeProvider.notifier).setVsAi(aiColor, difficulty);
    } else {
      ref.read(gameModeProvider.notifier).setTwoPlayer();
    }
    ref.read(customStartFenProvider.notifier).set(g.startFen);
    ref.read(selectedVariantProvider.notifier).set(variant);
    ref.invalidate(gameControllerProvider);
    final ok = ref
        .read(gameControllerProvider.notifier)
        .loadGame(g.moves, whiteMs: g.whiteMs, blackMs: g.blackMs);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).savedCorrupt)),
      );
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GameScreen()));
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, SavedGame g) async {
    final t = AppLocalizations.of(context);
    final ctl = TextEditingController(text: g.name);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.renameGameTitle),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: InputDecoration(labelText: t.gameName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctl.text.trim()),
            child: Text(t.save),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      ref.read(savedGamesProvider.notifier).rename(g.id, name);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final async = ref.watch(savedGamesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.menuResume)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (games) => games.isEmpty
            ? Center(child: Text(t.noSavedGames))
            : ListView(
                children: [
                  for (final g in games.reversed)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(g.name),
                        subtitle: Text('${g.ply} plies  ·  ${g.createdAt}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'rename') {
                              _rename(context, ref, g);
                            } else if (v == 'delete') {
                              ref
                                  .read(savedGamesProvider.notifier)
                                  .remove(g.id);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text(t.rename),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(t.delete),
                            ),
                          ],
                        ),
                        onTap: () => _resume(ref, context, g),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

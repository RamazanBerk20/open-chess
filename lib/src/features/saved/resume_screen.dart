import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/l10n/app_localizations.dart';
import 'package:open_chess/src/features/game/game_screen.dart';
import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/state/ai_provider.dart';
import 'package:open_chess/src/state/difficulty.dart';
import 'package:open_chess/src/state/game_mode.dart';
import 'package:open_chess/src/state/fen_repair.dart';
import 'package:open_chess/src/state/game_providers.dart';
import 'package:open_chess/src/state/lan_controller.dart';
import 'package:open_chess/src/state/l10n_labels.dart';
import 'package:open_chess/src/state/saved_games.dart';
import 'package:open_chess/src/state/time_control.dart';

/// Continue [g] as a local game (same-device, or vs-AI with its original
/// difficulty). A timed game can start paused, e.g. when offered on launch.
Future<void> resumeSavedGame(
  WidgetRef ref,
  BuildContext context,
  SavedGame g, {
  bool startPaused = false,
}) async {
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
  // The engine is stricter than older releases. A start position it now
  // rejects is reported; stale castling rights (e.g. an Atomic rook that was
  // blown up) can be dropped with the user's consent. The save is never
  // changed or deleted.
  var startFen = g.startFen;
  final error = fenLoadError(startFen, variant);
  if (error != null) {
    final t = AppLocalizations.of(context);
    final repaired = stripStaleCastling(startFen);
    if (repaired == null || fenLoadError(repaired, variant) != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.savedFenRejected(error))));
      return;
    }
    final open = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.staleCastlingTitle),
        content: Text(t.staleCastlingBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(t.openAnyway),
          ),
        ],
      ),
    );
    if (open != true || !context.mounted) return;
    startFen = repaired;
  }
  if (hasActiveLanSession(ref.read(lanProvider))) {
    ref.read(lanProvider.notifier).leave();
  }
  ref.read(aiControllerProvider.notifier).cancel();
  ref.read(selectedTimeControlProvider.notifier).set(tc);
  if (g.vsAi) {
    final params = g.difficultyParams;
    final difficulty = Difficulty.presets.firstWhere(
      (level) => level.name == g.difficultyName,
      orElse: () =>
          params == null ? Difficulty.normal : Difficulty.fromJson(params),
    );
    final aiColor = g.aiColorCode == 'white'
        ? PieceColor.white
        : PieceColor.black;
    ref.read(gameModeProvider.notifier).setVsAi(aiColor, difficulty);
  } else {
    ref.read(gameModeProvider.notifier).setTwoPlayer();
  }
  ref.read(customStartFenProvider.notifier).set(startFen);
  ref.read(selectedVariantProvider.notifier).set(variant);
  ref.invalidate(gameControllerProvider);
  final controller = ref.read(gameControllerProvider.notifier);
  final unplayed = controller.loadGame(
    g.moves,
    whiteMs: g.whiteMs,
    blackMs: g.blackMs,
    clockHistory: g.clockHistory,
  );
  if (unplayed > 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).savedPartialReplay(unplayed),
        ),
        duration: const Duration(seconds: 10),
      ),
    );
  }
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const GameScreen()));
  if (startPaused) controller.pause();
}

class ResumeScreen extends ConsumerWidget {
  const ResumeScreen({super.key});

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
    if (name != null && name.isNotEmpty && context.mounted) {
      await _write(
        context,
        ref.read(savedGamesProvider.notifier).rename(g.id, name),
      );
    }
  }

  /// Report a failed write instead of pretending it worked.
  Future<void> _write(BuildContext context, Future<void> write) async {
    final messenger = ScaffoldMessenger.of(context);
    final t = AppLocalizations.of(context);
    try {
      await write;
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t.gameSaveFailed)));
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
                        subtitle: Text(
                          '${t.pliesCount(g.ply)}  ·  ${g.createdAt}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'rename') {
                              _rename(context, ref, g);
                            } else if (v == 'delete') {
                              _write(
                                context,
                                ref
                                    .read(savedGamesProvider.notifier)
                                    .remove(g.id),
                              );
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
                        onTap: () => resumeSavedGame(ref, context, g),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

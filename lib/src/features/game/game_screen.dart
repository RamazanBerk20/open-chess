import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/l10n/app_localizations.dart';
import 'package:open_chess/src/features/analysis/analysis_screen.dart';
import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/state/pgn.dart';
import 'package:open_chess/src/widgets/pgn_export.dart';
import 'package:open_chess/src/state/ai_provider.dart';
import 'package:open_chess/src/state/difficulty.dart';
import 'package:open_chess/src/state/game_mode.dart';
import 'package:open_chess/src/state/game_phase.dart';
import 'package:open_chess/src/state/game_providers.dart';
import 'package:open_chess/src/state/clock_provider.dart';
import 'package:open_chess/src/state/l10n_labels.dart';
import 'package:open_chess/src/state/lan_controller.dart';
import 'package:open_chess/src/state/settings.dart';
import 'package:open_chess/src/widgets/bar_status.dart';
import 'package:open_chess/src/widgets/board_widget.dart';
import 'package:open_chess/src/widgets/hand_tray.dart';
import 'package:open_chess/src/widgets/captured_tray.dart';
import 'package:open_chess/src/widgets/clock_widget.dart';
import 'package:open_chess/src/widgets/game_result_panel.dart';
import 'package:open_chess/src/widgets/move_list.dart';
import 'package:open_chess/src/widgets/player_avatar.dart';
import 'package:open_chess/src/widgets/promotion_dialog.dart';
import 'package:open_chess/src/widgets/window_chrome.dart';

const _maxChatCharacters = 512;

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  // Prompts that must close if the game ends underneath them (a flag-fall
  // while choosing a promotion piece, a resignation while a draw offer is up).
  bool _promoOpen = false;
  bool _drawOpen = false;
  late final LanController _lan;
  late final bool _ownsLanSession;
  late final ProviderContainer _container;
  late final AppLifecycleListener _lifecycle;
  bool _disposed = false; // listeners can still fire while disposing
  int _aiRetries = 0; // engine refusals retried since the last move

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _lan = ref.read(lanProvider.notifier);
    _ownsLanSession = hasActiveLanSession(ref.read(lanProvider));
    // Backgrounding (or minimising) holds a local timed game and saves it.
    _lifecycle = AppLifecycleListener(onHide: _onBackground);
    // Kick off the engine's first reply when it is the side to move at the
    // start (AI plays White). Later replies are driven by the listeners in
    // build (game state change, or the engine becoming idle).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeAiMove(ref);
    });
  }

  void _onBackground() {
    final c = ref.read(gameControllerProvider.notifier);
    c.pause();
    c.autosave(flush: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _lifecycle.dispose();
    // Searches and the clock belong to this game; nothing may keep running
    // (or land a move) after the screen is gone.
    _container.read(gameControllerProvider.notifier).autosave(flush: false);
    _container.read(aiControllerProvider.notifier).cancel();
    _container.read(clockProvider.notifier).close();
    // The LAN provider is intentionally shared so setup can hand the active
    // stream to this route. Tear it down when this route leaves so events from
    // an old session cannot alter a later local game.
    if (_ownsLanSession) {
      _lan.leave();
    }
    super.dispose();
  }

  void _showChat(BuildContext context, {required bool spectatorOnly}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _ChatSheet(spectatorOnly: spectatorOnly),
      ),
    );
  }

  Future<void> _askDraw(AppLocalizations t) async {
    _drawOpen = true;
    final accept = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.drawOfferTitle),
        content: Text(t.drawOfferBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(t.decline),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(t.accept),
          ),
        ],
      ),
    );
    final answered = _drawOpen; // false when closed by the game ending
    _drawOpen = false;
    if (!mounted || !answered) return;
    ref.read(lanProvider.notifier).respondDraw(accept ?? false);
  }

  /// Close every open prompt (game over is terminal).
  void _closePrompts() {
    if (_promoOpen || _drawOpen) {
      _promoOpen = false;
      _drawOpen = false;
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _save(AppLocalizations t) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await _promptSaveName(context);
    if (name == null || !mounted) return;
    final stamp = DateTime.now().toString().split('.').first;
    final ok = await ref
        .read(gameControllerProvider.notifier)
        .saveGame(name.trim().isEmpty ? t.savedGameDefaultName(stamp) : name);
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? t.gameSaved : t.gameSaveFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    ref.listen<GameUiState>(gameControllerProvider, (prev, next) {
      if (_disposed) return;
      // Surface the promotion picker when the engine asks for one.
      if (next.pendingPromotion != null && prev?.pendingPromotion == null) {
        final color = next.view.sideToMove;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          _promoOpen = true;
          final choice = await showPromotionDialog(context, color);
          final answered = _promoOpen;
          _promoOpen = false;
          if (!context.mounted || !answered) return;
          final c = ref.read(gameControllerProvider.notifier);
          if (choice == null) {
            c.cancelPromotion();
          } else {
            c.completePromotion(choice);
          }
        });
      }
      if (next.isOver) _closePrompts();
      // Keep the unfinished game on disk after every move and at the end.
      if (prev == null ||
          prev.view.sanMoves.length != next.view.sanMoves.length ||
          prev.isOver != next.isOver) {
        ref.read(gameControllerProvider.notifier).autosave(flush: false);
      }
      if (prev?.view.sanMoves.length != next.view.sanMoves.length) {
        _aiRetries = 0;
      }
      // In vs-AI mode, let the engine reply when it is its turn.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_disposed) _maybeAiMove(ref);
      });
    });
    // An idle engine is a trigger too: a dropped or cancelled search must not
    // leave the AI side without a move.
    ref.listen<EngineState>(aiControllerProvider, (prev, next) {
      if (next is EngineIdle && next.error != null && !_disposed) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.engineFailed(next.error!))));
        // Not pinned forever: ask again once the refusal cooldown has passed
        // (a few times at most; a new move resets the allowance).
        if (_aiRetries++ < 3) {
          Future.delayed(const Duration(seconds: 6), () {
            if (mounted && !_disposed) _maybeAiMove(ref);
          });
        }
      }
      if (next is EngineIdle && !_disposed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_disposed) _maybeAiMove(ref);
        });
      }
    });
    // Surface an incoming LAN draw offer; close it when the offer goes away.
    ref.listen<LanGameState>(lanProvider, (prev, next) {
      if (_disposed) return;
      if (next.drawOfferIncoming && !(prev?.drawOfferIncoming ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              promptsAllowed(
                ref
                    .read(gameControllerProvider)
                    .phase(ref.read(gameModeProvider)),
              )) {
            _askDraw(t);
          }
        });
      }
      // Non-fatal transport notices (e.g. a move the host refused).
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizeLanError(t, next.error!))),
        );
      }
      if (!next.drawOfferIncoming && _drawOpen) {
        _drawOpen = false;
        Navigator.of(context).maybePop();
      }
    });

    final s = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final ai = ref.watch(aiControllerProvider);
    final mode = ref.watch(gameModeProvider);
    final phase = s.phase(mode);
    final timed = !s.view.clockInfinite;
    // Face-to-face table play (2P same-device on mobile) handles orientation by
    // rotating the far side's pieces, so per-turn auto-flip is pointless there.
    final faceToFace =
        !mode.vsAi && !mode.lan && (Platform.isAndroid || Platform.isIOS);

    return Scaffold(
      appBar: WindowAppBar(
        title: Text(mode.lan ? t.lanGame : t.game),
        // Desktop only: the state of play (all of it public, LAN included).
        center: Consumer(
          builder: (context, ref, _) {
            final clock = ref.watch(clockProvider);
            final timed = clock != null && !clock.infinite;
            return TwoPlayerBarStatus(
              sideToMove: s.view.sideToMove,
              moveNumber: s.view.fullmove,
              over: s.isOver,
              whiteMs: timed ? clock.whiteMs.toInt() : null,
              blackMs: timed ? clock.blackMs.toInt() : null,
            );
          },
        ),
        actions: [
          if (mode.lan)
            IconButton(
              tooltip: AppLocalizations.of(context).chat,
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () =>
                  _showChat(context, spectatorOnly: mode.lanSpectator),
            ),
          if (mode.lan && !mode.lanSpectator) ...[
            IconButton(
              tooltip: t.offerDraw,
              icon: const Icon(Icons.handshake),
              onPressed: s.isOver
                  ? null
                  : () => ref.read(lanProvider.notifier).offerDraw(),
            ),
            IconButton(
              tooltip: t.resign,
              icon: const Icon(Icons.flag),
              onPressed: s.isOver
                  ? null
                  : () => ref.read(lanProvider.notifier).resign(),
            ),
          ],
          if (!mode.lan && timed && !s.isOver)
            IconButton(
              tooltip: s.paused ? t.resumeGame : t.pauseGame,
              icon: Icon(s.paused ? Icons.play_arrow : Icons.pause),
              onPressed: s.paused
                  ? controller.resume
                  : (canPause(phase: phase, mode: mode, timed: timed)
                        ? controller.pause
                        : null),
            ),
          // The hot-seat "AI move" helper. In vs-AI the engine already owns
          // one side, so a second search would only race the real reply.
          if (!mode.lan && !mode.vsAi)
            IconButton(
              tooltip: t.aiMove,
              icon: ai.active
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.smart_toy),
              onPressed: (s.isOver || s.isBusy || ai.active)
                  ? null
                  : () {
                      final seed =
                          DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
                      final remaining = s.view.clockInfinite
                          ? null
                          : (s.view.sideToMove == PieceColor.white
                                ? s.view.clockWhiteMs.toInt()
                                : s.view.clockBlackMs.toInt());
                      ref
                          .read(aiControllerProvider.notifier)
                          .requestMove(
                            config: Difficulty.normal.toConfig(
                              seed,
                              remainingClockMs: remaining,
                            ),
                            purpose: SearchPurpose.hint,
                          );
                    },
            ),
          if (!mode.lan)
            IconButton(
              tooltip: t.saveGame,
              icon: const Icon(Icons.save_alt),
              onPressed: s.view.sanMoves.isEmpty ? null : () => _save(t),
            ),
          if (!mode.lan && !faceToFace)
            IconButton(
              tooltip: s.autoFlip ? t.autoFlipOn : t.autoFlipOff,
              icon: Icon(s.autoFlip ? Icons.sync : Icons.sync_disabled),
              onPressed: (s.isBusy || ai.active)
                  ? null
                  : controller.toggleAutoFlip,
            ),
          IconButton(
            tooltip: t.flipBoard,
            icon: const Icon(Icons.flip),
            onPressed: (s.isBusy || ai.active) ? null : controller.toggleFlip,
          ),
          if (!mode.lan)
            IconButton(
              tooltip: t.takeBack,
              icon: const Icon(Icons.undo),
              onPressed: (s.isBusy || ai.active) ? null : controller.undo,
            ),
          if (!mode.lan)
            IconButton(
              tooltip: t.newGame,
              icon: const Icon(Icons.refresh),
              onPressed: (s.isBusy || ai.active) ? null : controller.newGame,
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 720;
            // Block input during a promotion choice. While the AI thinks in
            // vs-AI mode the board stays live for premoves; the 2P manual-AI
            // button still locks the board.
            final Widget boardArea = s.paused
                ? _PausedBoard(onResume: controller.resume)
                : AbsorbPointer(
                    absorbing:
                        mode.lanSpectator ||
                        s.isBusy ||
                        (ai.active && !mode.vsAi),
                    child: _BoardArea(state: s),
                  );
            final panel = _SidePanel(state: s);
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Center(child: boardArea)),
                  SizedBox(width: 280, child: panel),
                ],
              );
            }
            return SingleChildScrollView(
              child: Column(
                children: [
                  boardArea,
                  SizedBox(height: 260, child: panel),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The board is hidden while paused so the pause cannot be used to think.
class _PausedBoard extends StatelessWidget {
  final VoidCallback onResume;
  const _PausedBoard({required this.onResume});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pause_circle_outline, size: 64),
            const SizedBox(height: 12),
            Text(t.gamePaused, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow),
              label: Text(t.resumeGame),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prompt for a save name. Returns null if cancelled.
Future<String?> _promptSaveName(BuildContext context) {
  final t = AppLocalizations.of(context);
  final ctl = TextEditingController(text: t.myGame);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(t.saveGame),
      content: TextField(
        controller: ctl,
        autofocus: true,
        decoration: InputDecoration(labelText: t.name),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(t.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(c, ctl.text),
          child: Text(t.save),
        ),
      ],
    ),
  );
}

/// Trigger an AI reply when it is the engine's turn in vs-AI mode.
void _maybeAiMove(WidgetRef ref) {
  final mode = ref.read(gameModeProvider);
  final g = ref.read(gameControllerProvider);
  if (!engineOwesReply(
    mode: mode,
    gameOver: g.isOver,
    busy: g.isBusy,
    paused: g.paused,
    sideToMove: g.view.sideToMove,
    engine: ref.read(aiControllerProvider),
  )) {
    return;
  }
  final seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
  final remaining = g.view.clockInfinite
      ? null
      : (mode.aiColor == PieceColor.white
            ? g.view.clockWhiteMs.toInt()
            : g.view.clockBlackMs.toInt());
  ref
      .read(aiControllerProvider.notifier)
      .requestMove(
        config: mode.difficulty.toConfig(seed, remainingClockMs: remaining),
      );
}

class _BoardArea extends ConsumerWidget {
  final GameUiState state;
  const _BoardArea({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    final view = state.view;
    final flipped = state.isFlipped;
    final bottom = flipped ? PieceColor.black : PieceColor.white;
    final top = bottom == PieceColor.white
        ? PieceColor.black
        : PieceColor.white;
    final advWhite = materialAdvantage(
      view.capturedByWhite,
      view.capturedByBlack,
    );
    final mode = ref.watch(gameModeProvider);
    final lan = ref.watch(lanProvider);

    Widget playerIdentity(PieceColor owner) {
      if (!mode.lan) return const SizedBox.shrink();
      final profile = owner == PieceColor.white
          ? lan.whiteProfile
          : lan.blackProfile;
      return SizedBox(
        width: 100,
        child: Row(
          children: [
            PlayerAvatar(profile: profile, radius: 12),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                profile.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget tray(PieceColor owner) {
      final captured = owner == PieceColor.white
          ? view.capturedByWhite
          : view.capturedByBlack;
      final adv = owner == PieceColor.white ? advWhite : -advWhite;
      return Row(
        children: [
          playerIdentity(owner),
          if (mode.lan) const SizedBox(width: 4),
          Expanded(
            child: CapturedTray(
              owner: owner,
              captured: captured,
              advantage: adv,
            ),
          ),
          PlayerClock(color: owner),
        ],
      );
    }

    // Crazyhouse reserve ("hand") rows, droppable by the side to move.
    final cz = view.variant == GameVariant.crazyhouse;
    final faceToFace =
        !mode.vsAi && !mode.lan && (Platform.isAndroid || Platform.isIOS);
    Widget handTray(PieceColor owner, bool upsideDown) {
      final counts = owner == PieceColor.white
          ? view.whiteHand
          : view.blackHand;
      final interactive =
          !state.isOver &&
          owner == view.sideToMove &&
          (!mode.vsAi || owner != mode.aiColor);
      return HandTray(
        owner: owner,
        counts: counts,
        interactive: interactive,
        selected: state.handPiece,
        onTap: controller.selectHand,
        upsideDown: upsideDown,
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        // Fixed-height tray rows keep the vertical chrome deterministic so the
        // board never overflows: 2*44 trays + 2*4 gaps + 2*8 padding = 112,
        // plus two reserve rows in Crazyhouse.
        const trayHeight = 44.0;
        const handHeight = 40.0;
        final chrome =
            trayHeight * 2 + 8 + 16 + (cz ? handHeight * 2 + 8 : 0.0);
        final side =
            (c.maxHeight.isFinite
                    ? min(c.maxWidth - 16, c.maxHeight - chrome)
                    : c.maxWidth - 16)
                .clamp(120.0, 1000.0);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: trayHeight, child: tray(top)),
                const SizedBox(height: 4),
                if (cz) ...[
                  SizedBox(
                    height: handHeight,
                    child: handTray(top, faceToFace),
                  ),
                  const SizedBox(height: 4),
                ],
                SizedBox(
                  width: side,
                  height: side,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final settings = ref.watch(settingsProvider);
                      final mode = ref.watch(gameModeProvider);
                      // Two players facing each other on a phone/tablet: rotate
                      // the far side's pieces so each reads them upright.
                      final faceToFace =
                          !mode.vsAi &&
                          !mode.lan &&
                          (Platform.isAndroid || Platform.isIOS);
                      return BoardWidget(
                        view: state.view,
                        flipped: state.isFlipped,
                        selected: state.selected,
                        targets: state.targets,
                        animate: state.animateLast,
                        premoves: state.premoves,
                        premoveFrom: state.premoveFrom,
                        premoveTargets: state.premoveTargets,
                        light: settings.theme.light,
                        dark: settings.theme.dark,
                        showHints: settings.showHints,
                        animMs: settings.animationMs,
                        faceToFace: faceToFace,
                        fogMask: controller.fogMask(),
                        onTap: controller.tapSquare,
                        onDrop: controller.dragMove,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                if (cz) ...[
                  SizedBox(height: handHeight, child: handTray(bottom, false)),
                  const SizedBox(height: 4),
                ],
                SizedBox(height: trayHeight, child: tray(bottom)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Reserve-piece order matching the Rust hand index (Pawn..Queen).

class _SidePanel extends StatelessWidget {
  final GameUiState state;
  const _SidePanel({required this.state});

  @override
  Widget build(BuildContext context) {
    // Fog of War hides private move information until the online match ends.
    final fogHide = state.view.variant == GameVariant.fogOfWar && !state.isOver;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusBanner(state: state),
          if (!fogHide) const _AiBanner(),
          if (state.isOver)
            Consumer(
              builder: (context, ref, _) {
                final mode = ref.read(gameModeProvider);
                final ctrl = ref.read(gameControllerProvider.notifier);
                return GameResultPanel(
                  onAnalyze: mode.lanSpectator
                      ? null
                      : () {
                          final moves = ctrl.movesUci();
                          if (moves.isEmpty) return;
                          final aiElo = mode.vsAi
                              ? mode.difficulty.targetElo
                              : null;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AnalysisScreen(
                                moves: moves,
                                startFen: ctrl.startFen,
                                variant: ctrl.variant,
                                knownWhiteElo: mode.aiColor == PieceColor.white
                                    ? aiElo
                                    : null,
                                knownBlackElo: mode.aiColor == PieceColor.black
                                    ? aiElo
                                    : null,
                              ),
                            ),
                          );
                        },
                  onPlayAgain: mode.lanSpectator
                      ? null
                      : () {
                          if (mode.lan) {
                            Navigator.of(context).maybePop();
                          } else {
                            ctrl.newGame();
                          }
                        },
                  onMainMenu: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  onExportPgn: mode.lanSpectator
                      ? null
                      : () => showPgnExport(
                          context,
                          buildPgn(
                            sanMoves: state.view.sanMoves,
                            status: state.view.status,
                            overlayResult: state.overlayResult,
                            youAreWhite: ref.read(lanProvider).youAreWhite,
                            startFen: ctrl.startFen,
                            variant: ctrl.variant,
                            white: mode.lan
                                ? ref.read(lanProvider).whiteProfile.username
                                : 'White',
                            black: mode.lan
                                ? ref.read(lanProvider).blackProfile.username
                                : 'Black',
                            date: pgnDate(DateTime.now()),
                          ),
                        ),
                );
              },
            ),
          const SizedBox(height: 8),
          Expanded(
            child: fogHide
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.visibility_off,
                          size: 40,
                          color: Colors.white38,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context).vFogOfWar,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  )
                : MoveList(sanMoves: state.view.sanMoves),
          ),
        ],
      ),
    );
  }
}

class _ChatSheet extends ConsumerStatefulWidget {
  final bool spectatorOnly;
  const _ChatSheet({required this.spectatorOnly});
  @override
  ConsumerState<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<_ChatSheet> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _send() {
    if (ref.read(lanProvider.notifier).sendChat(_ctl.text)) {
      _ctl.clear();
    } else if (_ctl.text.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).chatTooLong)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lan = ref.watch(lanProvider);
    final chat = widget.spectatorOnly ? lan.spectatorChat : lan.chat;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        height: 360,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                t.chat,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: chat.isEmpty
                  ? Center(
                      child: Text(
                        t.typeMessage,
                        style: TextStyle(color: cs.outline),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: chat.length,
                      itemBuilder: (_, i) {
                        final m = chat[i];
                        return Align(
                          alignment: m.mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: m.mine
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!m.mine && m.senderName != null)
                                  Text(
                                    m.senderName!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                Text(m.text),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctl,
                      textInputAction: TextInputAction.send,
                      maxLength: _maxChatCharacters,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                      decoration: InputDecoration(
                        hintText: t.typeMessage,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiBanner extends ConsumerWidget {
  const _AiBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ai = ref.watch(aiControllerProvider);
    if (ai is! EngineSearching) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    final eval = (ai.scoreCp / 100).toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ai.depth == 0
                    ? t.aiThinking
                    : '${t.aiDepthEval(ai.depth, eval)}'
                          '${ai.pv.isNotEmpty ? '  ${ai.pv.take(4).join(' ')}' : ''}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final GameUiState state;
  const _StatusBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final view = state.view;
    final t = AppLocalizations.of(context);
    if (state.overlayResult != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          localizeLanResult(t, state.overlayResult!),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
    }
    String text;
    Color color = Theme.of(context).colorScheme.secondaryContainer;
    switch (view.status) {
      case GameOutcome.ongoing:
        final w = view.sideToMove == PieceColor.white;
        text = view.inCheck
            ? (w ? t.whiteToMoveCheck : t.blackToMoveCheck)
            : (w ? t.whiteToMove : t.blackToMove);
      case GameOutcome.whiteWins:
        text = t.checkmateWhiteWins;
        color = Colors.green.shade200;
      case GameOutcome.blackWins:
        text = t.checkmateBlackWins;
        color = Colors.green.shade200;
      case GameOutcome.whiteWinsOnTime:
        text = t.whiteWinsOnTime;
        color = Colors.green.shade200;
      case GameOutcome.blackWinsOnTime:
        text = t.blackWinsOnTime;
        color = Colors.green.shade200;
      case GameOutcome.stalemate:
        text = t.drawStalemate;
        color = Colors.amber.shade200;
      case GameOutcome.drawFiftyMove:
        text = t.drawFiftyMove;
        color = Colors.amber.shade200;
      case GameOutcome.drawThreefold:
        text = t.drawThreefold;
        color = Colors.amber.shade200;
      case GameOutcome.drawInsufficientMaterial:
        text = t.drawInsufficient;
        color = Colors.amber.shade200;
    }
    // Three-check: show each side's delivered-check tally.
    if (view.variant == GameVariant.threeCheck) {
      text =
          '$text  ·  ${t.checksLabel} ${view.whiteChecks}–${view.blackChecks}';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}

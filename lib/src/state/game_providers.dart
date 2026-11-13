import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' show Uint64List;

import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/rust/api/net.dart' show netSendMove;
import 'package:open_chess/src/state/ai_provider.dart';
import 'package:open_chess/src/state/clock_provider.dart';
import 'package:open_chess/src/state/game_mode.dart';
import 'package:open_chess/src/state/game_phase.dart';
import 'package:open_chess/src/state/l10n_labels.dart';
import 'package:open_chess/src/state/saved_games.dart';
import 'package:open_chess/src/state/settings.dart';
import 'package:open_chess/src/state/time_control.dart';

/// UI state for a single same-device game. The authoritative chess state lives
/// in the Rust [ChessGame]; this holds the current rendered [GameView] plus
/// transient interaction state (selection, hint targets, board orientation).
class GameUiState {
  final GameView view;
  final int? selected;
  final Set<int> targets;
  final bool flipped; // manual flip (used when autoFlip is off)
  final bool autoFlip; // keep the side to move on the bottom
  final (int, int)? pendingPromotion; // (from, to) awaiting a piece choice
  final bool animateLast; // animate the last move's slide (false after undo)
  // Premoves (vs-AI): a queued chain of moves, played one per opponent reply.
  final List<(int, int)> premoves; // committed premove chain (in order)
  final int? premoveFrom; // square selected while choosing the next premove
  final Set<int> premoveTargets; // candidate destinations for that selection
  // A non-board outcome (resignation, draw agreement, disconnect, flag-fall).
  final String? overlayResult;
  // Crazyhouse: the reserve piece selected for dropping (0=Pawn..4=Queen), if any.
  final int? handPiece;
  // A local timed game on hold (pause button or app backgrounded).
  final bool paused;

  const GameUiState({
    required this.view,
    this.selected,
    this.targets = const {},
    this.flipped = false,
    this.autoFlip = false,
    this.pendingPromotion,
    this.animateLast = false,
    this.premoves = const [],
    this.premoveFrom,
    this.premoveTargets = const {},
    this.overlayResult,
    this.handPiece,
    this.paused = false,
  });

  /// Same state with only the given presentation fields changed.
  GameUiState keep({
    GameView? view,
    bool? flipped,
    bool? autoFlip,
    bool? paused,
  }) => GameUiState(
    view: view ?? this.view,
    selected: selected,
    targets: targets,
    flipped: flipped ?? this.flipped,
    autoFlip: autoFlip ?? this.autoFlip,
    pendingPromotion: pendingPromotion,
    animateLast: animateLast,
    premoves: premoves,
    premoveFrom: premoveFrom,
    premoveTargets: premoveTargets,
    overlayResult: overlayResult,
    handPiece: handPiece,
    paused: paused ?? this.paused,
  );

  GamePhase phase(GameMode mode) => gamePhase(
    status: view.status,
    overlay: overlayResult,
    paused: paused,
    pendingPromotion: pendingPromotion,
    mode: mode,
    sideToMove: view.sideToMove,
  );

  /// Whether the board should be drawn with Black at the bottom.
  bool get isFlipped =>
      autoFlip ? view.sideToMove == PieceColor.black : flipped;

  bool get isOver =>
      view.status != GameOutcome.ongoing || overlayResult != null;

  /// Input must be refused while a promotion choice is outstanding or paused.
  bool get isBusy => pendingPromotion != null || paused;
}

/// A custom start position (FEN) for "Play from Position"; null = standard start.
/// Setup screens set this (null for normal games) before building the game.
final customStartFenProvider =
    NotifierProvider<CustomStartFenController, String?>(
      CustomStartFenController.new,
    );

class CustomStartFenController extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? fen) => state = fen;
}

/// The chess variant for the next game (Standard for normal chess). Setup
/// screens set this before building the game.
final selectedVariantProvider =
    NotifierProvider<SelectedVariantController, GameVariant>(
      SelectedVariantController.new,
    );

class SelectedVariantController extends Notifier<GameVariant> {
  @override
  GameVariant build() => GameVariant.standard;
  void set(GameVariant v) => state = v;
}

final gameControllerProvider = NotifierProvider<GameController, GameUiState>(
  GameController.new,
);

class GameController extends Notifier<GameUiState> {
  // Every build / new game / resume / takeback starts a new session; engine
  // searches started in an older session are dropped.
  static int _sessions = 0;
  int _session = 0;
  int get session => _session;
  void _newSession() => _session = ++_sessions;

  /// Clock (white, black ms) just before each ply, persisted with saves so a
  /// takeback restores the real time even after a resume.
  final List<(int, int)> _clockBefore = [];
  late ChessGame _game;
  String? _startFen; // exact position this game (and any rematch) starts from
  GameVariant _variant = GameVariant.standard;

  @override
  GameUiState build() {
    final tc = ref.watch(selectedTimeControlProvider);
    _startFen = ref.read(customStartFenProvider);
    _variant = ref.read(selectedVariantProvider);
    final mode = ref.read(gameModeProvider);
    // Setup screens and resume already reject these variants, but keep the
    // engine boundary strict for legacy state or a programmatic caller.
    if (onlineOnlyVariants.contains(_variant) &&
        (!mode.lan || mode.lanSpectator)) {
      _variant = GameVariant.standard;
    }
    _game = _makeStart(tc);
    _startFen = _game.view().fen;
    _newSession();
    final flipped = mode.lan ? mode.lanMyColor == PieceColor.black : false;
    return GameUiState(view: _game.view(), flipped: flipped);
  }

  ChessGame _make(TimeControlOption tc) {
    return tc.isInfinite
        ? ChessGame.newGame()
        : ChessGame.newTimed(
            baseMinutes: tc.baseMinutes!,
            incrementSeconds: tc.incrementSeconds,
          );
  }

  /// Build the game from a saved/custom start FEN if one is set, preserving the
  /// selected rules and clock. Falls back to a normal game on a bad FEN.
  ChessGame _makeStart(TimeControlOption tc) {
    final fen = _startFen;
    if (fen != null) {
      try {
        return ChessGame.fromFenVariant(
          fen: fen,
          variant: _variant,
          baseMinutes: tc.baseMinutes ?? 0,
          incrementSeconds: tc.incrementSeconds,
        );
      } catch (_) {
        /* fall through to a normal game */
      }
    }
    if (_variant != GameVariant.standard) {
      return ChessGame.newVariant(
        variant: _variant,
        baseMinutes: tc.baseMinutes ?? 0,
        incrementSeconds: tc.incrementSeconds,
        chess960Index: _variant == GameVariant.chess960
            ? Random().nextInt(960)
            : 0,
      );
    }
    return _make(tc);
  }

  /// Cheap clock-only snapshot for the clock UI.
  ClockSnapshot clockSnapshotNow() => _game.clockSnapshot();

  /// Position-hash history (for the AI's repetition avoidance).
  Uint64List hashHistory() => _game.hashHistory();

  /// Fog of War: the squares the local LAN player can see (null off-fog).
  Set<int>? fogMask() {
    if (state.view.variant != GameVariant.fogOfWar) return null;
    final mode = ref.read(gameModeProvider);
    if (!mode.lan || mode.lanSpectator || mode.lanMyColor == null) return null;
    return _game.visibleSquares(viewer: mode.lanMyColor!).toSet();
  }

  /// Advance the running clock by [elapsedMs]; returns the new clock snapshot.
  /// When a flag falls, refreshes full state once so the board shows the result.
  ClockSnapshot tickClock(int elapsedMs) {
    if (state.isOver) return _game.clockSnapshot();
    _game.tick(elapsedMs: elapsedMs);
    final snap = _game.clockSnapshot();
    if (snap.over) state = state.keep(view: _game.view());
    return snap;
  }

  /// Store a LAN clock projection without running the local timeout state
  /// machine. The next local move can then apply its Fischer increment from a
  /// current display value while the host remains the sole flag authority.
  void lanSetProjectedClock(ClockSnapshot snapshot) {
    if (snapshot.infinite || state.isOver) return;
    _game.setClockMs(whiteMs: snapshot.whiteMs, blackMs: snapshot.blackMs);
  }

  GameUiState _idle({
    int? selected,
    Set<int> targets = const {},
    (int, int)? pending,
    bool? animateLast,
    bool keepPremove = true,
    List<(int, int)>? premoves,
    String? overlayResult,
  }) {
    return GameUiState(
      view: _game.view(),
      selected: selected,
      targets: targets,
      flipped: state.flipped,
      autoFlip: state.autoFlip,
      pendingPromotion: pending,
      // Preserve the slide flag across non-move changes so an in-flight slide
      // isn't cut short by a selection; callers override on play/undo.
      animateLast: animateLast ?? state.animateLast,
      // Preserve the queued premove chain across the opponent's move; clear when
      // it is executed/discarded. `premoves` overrides; else `keepPremove` keeps
      // the current chain. Premove selection (from/targets) ends on any idle.
      premoves: premoves ?? (keepPremove ? state.premoves : const []),
      overlayResult: overlayResult ?? state.overlayResult,
      paused: state.paused,
    );
  }

  /// Build a premove selection/queue state. `premoves` defaults to the current
  /// chain; `from`/`targets` describe the in-progress next-premove selection.
  GameUiState _premoveState({
    List<(int, int)>? premoves,
    int? from,
    Set<int> targets = const {},
  }) {
    return GameUiState(
      view: _game.view(),
      flipped: state.flipped,
      autoFlip: state.autoFlip,
      animateLast: state.animateLast,
      premoves: premoves ?? state.premoves,
      premoveFrom: from,
      premoveTargets: targets,
      overlayResult: state.overlayResult,
      paused: state.paused,
    );
  }

  /// The board as it would look after the queued premoves (raw relocations),
  /// so a chained premove is selected/rendered from the right squares.
  List<SquarePiece?> _previewBoard() {
    final board = state.view.board;
    if (state.premoves.isEmpty) return board;
    final b = List<SquarePiece?>.of(board);
    for (final (f, t) in state.premoves) {
      b[t] = b[f];
      b[f] = null;
    }
    return b;
  }

  /// Flattened [f0,t0,f1,t1,…] of the queued premoves for the Rust bridge.
  List<int> _flatPremoves() => [
    for (final (f, t) in state.premoves) ...[f, t],
  ];

  /// Premove targets for `sq` on the board after the queued premoves.
  Set<int> _premoveTargetsAfter(int sq) =>
      _game.premoveTargetsAfter(premoves: _flatPremoves(), from: sq).toSet();

  bool _isHumanTurn() {
    final mode = ref.read(gameModeProvider);
    if (mode.vsAi) return state.view.sideToMove != mode.aiColor;
    if (mode.lan) return state.view.sideToMove == mode.lanMyColor;
    return true;
  }

  PieceColor? _humanColor() {
    final mode = ref.read(gameModeProvider);
    if (mode.vsAi) {
      return mode.aiColor == PieceColor.white
          ? PieceColor.black
          : PieceColor.white;
    }
    if (mode.lan) return mode.lanMyColor;
    return null;
  }

  void newGame() {
    // Stop any in-flight AI search so it can't land a stale move on the new game.
    ref.read(aiControllerProvider.notifier).cancel();
    _game = _makeStart(ref.read(selectedTimeControlProvider));
    _startFen = _game.view().fen;
    _clockBefore.clear();
    _newSession();
    state = GameUiState(
      view: _game.view(),
      flipped: state.flipped,
      autoFlip: state.autoFlip,
    );
    ref.invalidate(clockProvider); // restart the ticker for the new game
  }

  void undo() {
    if (state.isBusy) return;
    final n = takebackPlies(
      mode: ref.read(gameModeProvider),
      sideToMove: state.view.sideToMove,
      plies: state.view.sanMoves.length,
    );
    if (n == 0) return;
    ref.read(aiControllerProvider.notifier).cancel();
    for (var i = 0; i < n; i++) {
      _undoPly();
    }
    _newSession();
    state = _idle(animateLast: false, keepPremove: false);
    ref.invalidate(
      clockProvider,
    ); // restart the ticker (also after a flag-fall)
  }

  /// Take back one ply and restore the clock recorded before it.
  bool _undoPly() {
    if (!_game.undo()) return false;
    if (_clockBefore.isNotEmpty) {
      final (w, b) = _clockBefore.removeLast();
      if (!_game.clockSnapshot().infinite) {
        _game.setClockMs(whiteMs: w, blackMs: b);
      }
    }
    return true;
  }

  /// Run a bridge move call, recording the pre-move clock when it adds a ply.
  /// A bridge error counts as a rejected move instead of crashing the UI.
  T _move<T>(T Function() apply, T rejected) {
    final before = _game.clockSnapshot();
    final T r;
    try {
      r = apply();
    } catch (_) {
      return rejected;
    }
    if (_game.moveHistoryUci().length > _clockBefore.length) {
      _clockBefore.add((before.whiteMs.toInt(), before.blackMs.toInt()));
    }
    return r;
  }

  /// Hold a local timed game: stops the clock, the engine and input.
  void pause() {
    final mode = ref.read(gameModeProvider);
    if (!canPause(
      phase: state.phase(mode),
      mode: mode,
      timed: !_game.clockSnapshot().infinite,
    )) {
      return;
    }
    ref.read(clockProvider.notifier).pause();
    ref.read(aiControllerProvider.notifier).cancel();
    state = state.keep(paused: true);
  }

  void resume() {
    if (!state.paused) return;
    state = state.keep(paused: false);
    ref.read(clockProvider.notifier).resume();
  }

  void toggleFlip() {
    if (state.isBusy) return;
    state = state.keep(flipped: !state.flipped, autoFlip: false);
  }

  void toggleAutoFlip() {
    if (state.isBusy) return;
    state = state.keep(autoFlip: !state.autoFlip);
  }

  /// Tap-to-move handler.
  void tapSquare(int sq) {
    if (state.isOver || state.isBusy) return;
    if (!_isHumanTurn()) {
      // Premove during the opponent's turn (vs-AI or LAN). No-op in hot-seat:
      // _humanColor() is null there and every turn is already "yours".
      _premoveTap(sq);
      return;
    }
    // Crazyhouse: a reserve piece is armed — tap a highlighted square to drop it.
    if (state.handPiece != null) {
      if (state.targets.contains(sq)) {
        dropPiece(sq);
      } else {
        state = _idle();
      }
      return;
    }
    final view = state.view;
    final piece = view.board[sq];
    final sel = state.selected;

    if (sel == null) {
      if (piece != null && piece.color == view.sideToMove) {
        state = _idle(
          selected: sq,
          targets: _game.legalTargets(from: sq).toSet(),
        );
      }
      return;
    }
    if (sq == sel) {
      state = _idle();
      return;
    }
    if (state.targets.contains(sq)) {
      _attempt(sel, sq);
      return;
    }
    if (piece != null && piece.color == view.sideToMove) {
      state = _idle(
        selected: sq,
        targets: _game.legalTargets(from: sq).toSet(),
      );
    } else {
      state = _idle();
    }
  }

  /// Premove tap handler (used during the opponent's turn).
  void _premoveTap(int sq) {
    final hc = _humanColor();
    if (hc == null) return;
    // Select/render from the board as it will look after the queued premoves,
    // so the same piece can be chained move after move.
    final piece = _previewBoard()[sq];
    final selFrom = state.premoveFrom;

    if (selFrom == null) {
      if (piece != null && piece.color == hc) {
        state = _premoveState(from: sq, targets: _premoveTargetsAfter(sq));
      } else {
        state = _premoveState(
          premoves: const [],
        ); // tap empty/enemy → clear chain
      }
      return;
    }
    if (sq == selFrom) {
      state = _premoveState(); // cancel the in-progress selection (keep chain)
      return;
    }
    if (state.premoveTargets.contains(sq)) {
      state = _premoveState(
        premoves: [...state.premoves, (selFrom, sq)],
      ); // queue
      return;
    }
    if (piece != null && piece.color == hc) {
      state = _premoveState(from: sq, targets: _premoveTargetsAfter(sq));
    } else {
      state = _premoveState(); // cancel selection, keep the chain
    }
  }

  /// Drag-to-move handler (drop `from` piece onto `to`).
  void dragMove(int from, int to) {
    if (state.isOver || state.isBusy) return;
    if (!_isHumanTurn()) {
      // Premove during the opponent's turn (vs-AI or LAN; no-op in hot-seat).
      final hc = _humanColor();
      final piece = _previewBoard()[from];
      if (hc != null && piece != null && piece.color == hc) {
        // Validate the destination like the tap path, so no bogus premove
        // highlight is shown for a move that can never fire.
        final targets = _premoveTargetsAfter(from);
        if (targets.contains(to)) {
          state = _premoveState(premoves: [...state.premoves, (from, to)]);
        } else {
          state = _premoveState(from: from, targets: targets);
        }
      }
      return;
    }
    final piece = state.view.board[from];
    if (piece == null || piece.color != state.view.sideToMove) return;
    if (!_game.legalTargets(from: from).contains(to)) {
      state = _idle(
        selected: from,
        targets: _game.legalTargets(from: from).toSet(),
      );
      return;
    }
    _attempt(from, to);
  }

  /// Crazyhouse: arm a reserve piece for dropping (highlights legal squares).
  void selectHand(int piece) {
    if (state.isOver || state.isBusy || !_isHumanTurn()) return;
    final targets = _game.dropTargets(piece: piece).toSet();
    if (targets.isEmpty) return;
    state = GameUiState(
      view: _game.view(),
      flipped: state.flipped,
      autoFlip: state.autoFlip,
      handPiece: piece,
      targets: targets,
    );
  }

  /// Crazyhouse: drop the armed reserve piece onto `to`.
  void dropPiece(int to) {
    final piece = state.handPiece;
    if (piece == null) return;
    final clock = ref.read(clockProvider.notifier);
    clock.flushElapsed();
    if (state.isOver) {
      state = _idle();
      clock.refreshSnapshot();
      return;
    }
    final outcome = _move(
      () => _game.playDrop(piece: piece, to: to),
      MoveOutcome.illegal,
    );
    state = _idle(animateLast: false);
    if (outcome == MoveOutcome.played) {
      // Send the drop to the LAN peer (no-op off-LAN): UCI "N@e4" form.
      _afterLocalMove('${const ['P', 'N', 'B', 'R', 'Q'][piece]}@${_su(to)}');
      _feedback();
    }
    clock.refreshSnapshot();
  }

  void _attempt(int from, int to) {
    final clock = ref.read(clockProvider.notifier);
    clock.flushElapsed(); // charge the mover's time at the move instant
    if (state.isOver) {
      // The mover flagged while thinking — the move doesn't count.
      state = _idle();
      clock.refreshSnapshot();
      return;
    }
    final outcome = _move(
      () => _game.play(from: from, to: to, promotion: null),
      MoveOutcome.illegal,
    );
    switch (outcome) {
      case MoveOutcome.played:
        state = _idle(animateLast: true);
        _afterLocalMove('${_su(from)}${_su(to)}');
        _feedback();
      case MoveOutcome.needsPromotion:
        state = _idle(pending: (from, to));
      case MoveOutcome.illegal:
        state = _idle();
    }
    clock.refreshSnapshot();
  }

  /// Apply a move chosen by the AI (UCI form), charging its think time.
  void aiPlayUci(String uci) {
    final clock = ref.read(clockProvider.notifier);
    clock.flushElapsed();
    if (state.isOver) {
      state = _idle();
      clock.refreshSnapshot();
      return;
    }
    if (_move(() => _game.playUci(uci: uci), false)) {
      state = _idle(animateLast: true);
      _feedback();
    }
    clock.refreshSnapshot();
    _tryExecutePremove();
  }

  /// After the opponent moves, play the front of the premove chain if it is now
  /// legal; keep the rest for the next reply. If it's no longer legal, the chain
  /// is broken — discard all of it.
  void _tryExecutePremove() {
    if (state.premoves.isEmpty || state.isOver || !_isHumanTurn()) return;
    final pm = state.premoves.first;
    final rest = state.premoves.sublist(1);
    final clock = ref.read(clockProvider.notifier);
    clock.flushElapsed();
    if (state.isOver) {
      state = _idle(premoves: const []);
      clock.refreshSnapshot();
      return;
    }
    var outcome = _move(
      () => _game.play(from: pm.$1, to: pm.$2, promotion: null),
      MoveOutcome.illegal,
    );
    var promoted = false;
    if (outcome == MoveOutcome.needsPromotion) {
      // Premove promotions auto-queen (standard behaviour).
      outcome = _move(
        () => _game.play(from: pm.$1, to: pm.$2, promotion: PieceKind.queen),
        MoveOutcome.illegal,
      );
      promoted = true;
    }
    if (outcome == MoveOutcome.played) {
      state = _idle(premoves: rest, animateLast: true);
      // Relay to the LAN peer (no-op off-LAN); auto-queen needs the promo char.
      _afterLocalMove('${_su(pm.$1)}${_su(pm.$2)}${promoted ? 'q' : ''}');
      clock.refreshSnapshot();
      _feedback();
    } else {
      state = _idle(premoves: const [], animateLast: false);
      clock.refreshSnapshot();
    }
  }

  void completePromotion(PieceKind kind) {
    final p = state.pendingPromotion;
    if (p == null) return;
    final clock = ref.read(clockProvider.notifier);
    clock.flushElapsed();
    if (state.isOver) {
      state = _idle();
      clock.refreshSnapshot();
      return;
    }
    final outcome = _move(
      () => _game.play(from: p.$1, to: p.$2, promotion: kind),
      MoveOutcome.illegal,
    );
    state = _idle(animateLast: true);
    clock.refreshSnapshot();
    if (outcome == MoveOutcome.played) {
      _afterLocalMove('${_su(p.$1)}${_su(p.$2)}${_promoChar(kind)}');
    }
  }

  void cancelPromotion() {
    state = _idle();
  }

  // ---- LAN ----

  void _afterLocalMove(String uci) {
    if (!ref.read(gameModeProvider).lan) return;
    final snap = _game.clockSnapshot();
    netSendMove(uci: uci, whiteMs: snap.whiteMs, blackMs: snap.blackMs);
  }

  /// Move sound + haptic feedback, gated by settings. Uses the last SAN to
  /// distinguish check/mate (alert) from a normal move/capture (click).
  void _feedback() {
    final s = ref.read(settingsProvider);
    if (s.haptics) HapticFeedback.lightImpact();
    if (!s.soundOn) return;
    final sans = state.view.sanMoves;
    if (sans.isEmpty) return;
    final last = sans.last;
    // Fog of War: a check alert would reveal hidden attackers.
    final fog = state.view.variant == GameVariant.fogOfWar;
    if (!fog && (last.contains('#') || last.contains('+'))) {
      SystemSound.play(SystemSoundType.alert);
    } else {
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Apply a move received from the LAN peer (already validated in Rust) and
  /// reconcile the clock from the message.
  void lanApplyRemote(String uci, int whiteMs, int blackMs) {
    if (state.isOver) return;
    if (_move(() => _game.playUci(uci: uci), false)) {
      _game.setClockMs(whiteMs: whiteMs, blackMs: blackMs);
      state = _idle(animateLast: true);
      ref.read(clockProvider.notifier).resetAndRefresh();
      _feedback();
      _tryExecutePremove(); // fire a queued premove now that it's our turn
    } else {
      // The peer sent a move our board rejects — the positions have diverged.
      // Abort loudly instead of silently freezing on a stale board.
      lanSetResult(LanResultCode.boardDesync);
    }
  }

  /// Apply the host-authoritative LAN flag fall. The host only emits this for
  /// the side currently on move, so ticking zero milliseconds latches the
  /// existing clock model's normal on-time result without inventing a second
  /// result representation.
  void lanApplyTimeout(PieceColor loser) {
    if (state.isOver) return;
    var snap = _game.clockSnapshot();
    if (snap.infinite) return;
    // A client can optimistically submit a move in the narrow interval before
    // the host's clock tick rejects it. The authoritative timeout belongs to
    // the pre-move side, so roll that local optimistic ply back first.
    if (snap.running != loser && _undoPly()) {
      snap = _game.clockSnapshot();
    }
    _game.setClockMs(
      whiteMs: loser == PieceColor.white ? 0 : snap.whiteMs,
      blackMs: loser == PieceColor.black ? 0 : snap.blackMs,
    );
    _game.tick(elapsedMs: 0);
    state = _idle(animateLast: false, keepPremove: false);
    ref.read(clockProvider.notifier).resetAndRefresh();
  }

  /// The host refused our last move [uci]: take it back locally if it is the
  /// last ply, so the mirror matches the host again.
  void lanRevertLocal(String uci) {
    final history = _game.moveHistoryUci();
    if (state.isOver || history.isEmpty || history.last != uci) return;
    if (_undoPly()) {
      state = _idle(animateLast: false, keepPremove: false);
      ref.read(clockProvider.notifier).resetAndRefresh();
    }
  }

  /// Replace the local board with the authoritative position sent to a LAN
  /// spectator. A current-position FEN deliberately becomes this view's start:
  /// spectators join live and do not receive earlier private move history.
  void lanLoadSnapshot({
    required String fen,
    required GameVariant variant,
    required int baseMinutes,
    required int incrementSeconds,
    required int whiteMs,
    required int blackMs,
    required int whiteChecks,
    required int blackChecks,
    required List<int> whiteHand,
    required List<int> blackHand,
    required BigInt promoted,
  }) {
    try {
      final g = ChessGame.fromFenVariant(
        fen: fen,
        variant: variant,
        baseMinutes: baseMinutes,
        incrementSeconds: incrementSeconds,
      );
      g.restoreVariantState(
        whiteChecks: whiteChecks,
        blackChecks: blackChecks,
        whiteHand: whiteHand,
        blackHand: blackHand,
        promoted: promoted,
      );
      _game = g;
    } catch (_) {
      // The host's snapshot is not a position we accept: say so, don't crash.
      lanSetResult(LanResultCode.boardDesync);
      return;
    }
    _variant = variant;
    _startFen = fen;
    _clockBefore.clear();
    _newSession();
    _game.setClockMs(whiteMs: whiteMs, blackMs: blackMs);
    state = GameUiState(view: _game.view());
    ref.invalidate(clockProvider);
  }

  /// Show a non-board result (resignation, draw agreed, disconnect).
  /// The first result is final: a late draw acceptance, resignation, or
  /// disconnect after the game ended changes nothing.
  void lanSetResult(String text) {
    final overlay = applyResult(state.phase(ref.read(gameModeProvider)), text);
    if (overlay == null) return;
    state = _idle(overlayResult: overlay, keepPremove: false);
    ref.read(clockProvider.notifier).gameOver();
  }

  /// Moves played so far (UCI) — for post-game analysis.
  List<String> movesUci() => _game.moveHistoryUci();

  /// The custom start FEN this game began from (null = standard start) — used
  /// for PGN export of games started via "Play from Position".
  String get startFen =>
      _startFen ?? 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  GameVariant get variant => _variant;

  // ---- Saved games ----

  /// The current game as a [SavedGame], or null before the first move.
  SavedGame? snapshot(String name, {bool flush = true}) {
    final moves = _game.moveHistoryUci();
    if (moves.isEmpty) return null;
    // Capture the same moment users clicked Save rather than the ticker's last
    // 100 ms snapshot, so a resumed timed game does not gain thinking time.
    if (flush) ref.read(clockProvider.notifier).flushElapsed();
    final now = DateTime.now();
    final tc = ref.read(selectedTimeControlProvider);
    final clock = _game.clockSnapshot();
    final mode = ref.read(gameModeProvider);
    return SavedGame(
      id: now.microsecondsSinceEpoch.toString(),
      name: name,
      moves: moves,
      createdAt: now.toString().split('.').first,
      startFen: startFen,
      variantCode: variantCode(_variant),
      baseMinutes: tc.isInfinite ? null : tc.baseMinutes,
      incrementSeconds: tc.incrementSeconds,
      whiteMs: clock.infinite ? null : clock.whiteMs.toInt(),
      blackMs: clock.infinite ? null : clock.blackMs.toInt(),
      vsAi: mode.vsAi,
      aiColorCode: mode.aiColor == PieceColor.white ? 'white' : 'black',
      difficultyName: mode.vsAi ? mode.difficulty.name : null,
      difficultyParams: mode.vsAi ? mode.difficulty.toJson() : null,
      clockHistory: clock.infinite || _clockBefore.length != moves.length
          ? null
          : List.of(_clockBefore),
    );
  }

  /// Persist the current game under [name]. Completes with false when there
  /// was nothing to save or the write failed.
  Future<bool> saveGame(String name) async {
    final g = snapshot(name);
    if (g == null) return false;
    try {
      await ref.read(savedGamesProvider.notifier).add(g);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Autosave the current local game (cleared once it is over). LAN
  /// games are owned by the host and never autosaved.
  void autosave({bool flush = true}) {
    if (ref.read(gameModeProvider).lan) return;
    final autosaved = ref.read(autosaveProvider.notifier);
    if (state.isOver) {
      autosaved.put(null); // finished: nothing to resume
      return;
    }
    // An empty board (new game not started yet) keeps the previous unfinished
    // game on offer instead of erasing it.
    final g = snapshot('', flush: flush);
    if (g != null) autosaved.put(g);
  }

  /// Replay a saved move list onto the current (freshly built) game. The caller
  /// invalidates this provider with an infinite time control first. Replay
  /// stops at the first move the current rules reject (a save from an older
  /// release, or a corrupt one); returns how many saved moves were NOT replayed
  /// (0 = complete). The save itself is never touched.
  int loadGame(
    List<String> moves, {
    int? whiteMs,
    int? blackMs,
    List<(int, int)>? clockHistory,
  }) {
    ref.read(aiControllerProvider.notifier).cancel();
    var unplayed = 0;
    for (var i = 0; i < moves.length; i++) {
      if (!_move(() => _game.playUci(uci: moves[i]), false)) {
        unplayed = moves.length - i;
        break; // don't apply later plies onto a desynced position
      }
    }
    final ok = unplayed == 0;
    if (whiteMs != null && blackMs != null) {
      _game.setClockMs(whiteMs: whiteMs, blackMs: blackMs);
      // The replay recorded fresh-game clocks. Use the saved per-ply history;
      // for older saves without one, never hand back more than the save had.
      final n = _clockBefore.length;
      _clockBefore
        ..clear()
        ..addAll(
          ok && clockHistory != null && clockHistory.length == n
              ? clockHistory
              : List.filled(n, (whiteMs, blackMs)),
        );
    }
    _newSession();
    state = GameUiState(view: _game.view());
    ref.invalidate(clockProvider);
    return unplayed;
  }

  static String _su(int sq) =>
      '${String.fromCharCode(97 + sq % 8)}${String.fromCharCode(49 + sq ~/ 8)}';

  static String _promoChar(PieceKind k) => switch (k) {
    PieceKind.queen => 'q',
    PieceKind.rook => 'r',
    PieceKind.bishop => 'b',
    PieceKind.knight => 'n',
    _ => 'q',
  };
}

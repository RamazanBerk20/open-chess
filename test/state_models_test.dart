import 'package:flutter_test/flutter_test.dart';
import 'package:open_chess/l10n/app_localizations_en.dart';

import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/state/ai_provider.dart';
import 'package:open_chess/src/state/analysis_provider.dart';
import 'package:open_chess/src/state/clock_provider.dart';
import 'package:open_chess/src/state/difficulty.dart';
import 'package:open_chess/src/state/game_mode.dart';
import 'package:open_chess/src/state/game_phase.dart';
import 'package:open_chess/src/state/l10n_labels.dart';
import 'package:open_chess/src/state/lan_controller.dart';
import 'package:open_chess/src/state/multi_board_session.dart';

const _vsAiBlack = GameMode(
  vsAi: true,
  aiColor: PieceColor.black,
  difficulty: Difficulty.normal,
);
const _lanWhite = GameMode(lan: true, lanMyColor: PieceColor.white);

EngineSearching _search({int id = 1, int session = 7, String fen = 'f'}) =>
    EngineSearching(
      id: id,
      session: session,
      fen: fen,
      purpose: SearchPurpose.reply,
    );

void main() {
  group('engine search', () {
    test('start, progress, finish', () {
      var s = reduceEngine(const EngineIdle(), SearchStarted(_search()));
      s = reduceEngine(s, const SearchProgress(1, 4, 30, ['e2e4']));
      expect((s as EngineSearching).depth, 4);
      expect(reduceEngine(s, const SearchFinished(1)), isA<EngineIdle>());
    });

    test('events of an older search are ignored', () {
      final s = _search(id: 2);
      expect(reduceEngine(s, const SearchFinished(1)), same(s));
      expect(reduceEngine(s, const SearchProgress(1, 9, 0, [])), same(s));
    });

    test('cancel always idles', () {
      expect(
        reduceEngine(_search(), const SearchCancelled()),
        isA<EngineIdle>(),
      );
    });

    test('a result from another session or position is dropped', () {
      bool play({int session = 7, String fen = 'f', bool over = false}) =>
          shouldPlaySearchResult(
            search: _search(),
            bestUci: 'e2e4',
            session: session,
            fen: fen,
            gameOver: over,
            lan: false,
            paused: false,
          );
      expect(play(), isTrue);
      expect(play(session: 8), isFalse); // new game / resume / takeback
      expect(play(fen: 'g'), isFalse);
      expect(play(over: true), isFalse);
    });

    test('an idle engine owes the AI reply on its turn (no tap needed)', () {
      bool owes({
        EngineState engine = const EngineIdle(),
        PieceColor side = PieceColor.black,
        bool paused = false,
      }) => engineOwesReply(
        mode: _vsAiBlack,
        gameOver: false,
        busy: false,
        paused: paused,
        sideToMove: side,
        engine: engine,
      );
      expect(owes(), isTrue);
      expect(owes(engine: _search()), isFalse);
      expect(owes(side: PieceColor.white), isFalse);
      expect(owes(paused: true), isFalse);
    });
  });

  group('clock', () {
    test('start picks the phase', () {
      expect(
        reduceClock(
          const ClockOff(),
          const ClockStart(infinite: true, lan: false),
        ),
        isA<ClockOff>(),
      );
      expect(
        reduceClock(
          const ClockOff(),
          const ClockStart(infinite: false, lan: true),
        ),
        isA<ClockDisplayOnly>(),
      );
      expect(
        reduceClock(
          const ClockOff(),
          const ClockStart(infinite: false, lan: false, over: true),
        ),
        isA<ClockStopped>(),
      );
    });

    test('pause and resume only for a local running clock', () {
      final paused = reduceClock(const ClockRunning(), const ClockPause());
      expect(paused, isA<ClockPaused>());
      expect(paused.ticks, isFalse);
      expect(reduceClock(paused, const ClockResume()), isA<ClockRunning>());
      expect(
        reduceClock(const ClockDisplayOnly(), const ClockPause()),
        isA<ClockDisplayOnly>(),
      );
    });

    test('every game end stops the display, LAN included', () {
      for (final p in const <ClockPhase>[
        ClockRunning(),
        ClockDisplayOnly(),
        ClockPaused(),
      ]) {
        final s = reduceClock(p, const ClockGameOver());
        expect(s, isA<ClockStopped>());
        expect(s.ticks, isFalse);
      }
    });

    test('closing the screen turns the clock off', () {
      expect(
        reduceClock(const ClockRunning(), const ClockClose()),
        isA<ClockOff>(),
      );
    });
  });

  group('game phase and end of game', () {
    GamePhase phase({
      GameOutcome status = GameOutcome.ongoing,
      String? overlay,
      bool paused = false,
      (int, int)? promo,
      GameMode mode = const GameMode(),
      PieceColor side = PieceColor.white,
    }) => gamePhase(
      status: status,
      overlay: overlay,
      paused: paused,
      pendingPromotion: promo,
      mode: mode,
      sideToMove: side,
    );

    test('derives one phase', () {
      expect(phase(), isA<PhaseAwaitingLocal>());
      expect(phase(paused: true), isA<PhasePaused>());
      expect(phase(promo: (52, 60)), isA<PhaseAwaitingPromotion>());
      expect(
        phase(mode: _vsAiBlack, side: PieceColor.black),
        isA<PhaseAwaitingEngine>(),
      );
      expect(
        phase(mode: _lanWhite, side: PieceColor.black),
        isA<PhaseAwaitingRemote>(),
      );
      expect(phase(status: GameOutcome.stalemate), isA<PhaseOver>());
    });

    test('the first result is final', () {
      final over = phase(overlay: LanResultCode.opponentResigned);
      expect(applyResult(over, LanResultCode.drawAgreed), isNull);
      expect(applyResult(phase(status: GameOutcome.whiteWins), 'x'), isNull);
      expect(
        applyResult(phase(), LanResultCode.drawAgreed),
        LanResultCode.drawAgreed,
      );
      expect(promptsAllowed(over), isFalse);
    });

    test('pause is for local timed games only', () {
      expect(
        canPause(phase: phase(), mode: const GameMode(), timed: true),
        isTrue,
      );
      expect(
        canPause(phase: phase(), mode: const GameMode(), timed: false),
        isFalse,
      );
      expect(
        canPause(
          phase: phase(mode: _lanWhite),
          mode: _lanWhite,
          timed: true,
        ),
        isFalse,
      );
    });

    test('vs-AI takeback removes one ply when the human moved last', () {
      expect(
        takebackPlies(mode: _vsAiBlack, sideToMove: PieceColor.black, plies: 5),
        1,
      );
      expect(
        takebackPlies(mode: _vsAiBlack, sideToMove: PieceColor.white, plies: 4),
        2,
      );
      expect(
        takebackPlies(mode: _vsAiBlack, sideToMove: PieceColor.white, plies: 1),
        0,
      );
      expect(
        takebackPlies(
          mode: const GameMode(),
          sideToMove: PieceColor.white,
          plies: 3,
        ),
        1,
      );
      expect(
        takebackPlies(mode: _lanWhite, sideToMove: PieceColor.white, plies: 3),
        0,
      );
    });
  });

  group('LAN session', () {
    test('connect, offer, end; a late offer after the end is ignored', () {
      var s = reduceLan(const LanIdle(), const LanStart(LanRole.join));
      expect(s, isA<LanConnecting>());
      s = reduceLan(s, const LanConnected(spectator: false));
      s = reduceLan(s, const LanDrawOffered());
      expect((s as LanLive).drawOfferIncoming, isTrue);
      s = reduceLan(s, const LanMatchEnded());
      expect(s, isA<LanEnded>());
      expect(reduceLan(s, const LanDrawOffered()), same(s));
      expect(
        reduceLan(s, const LanLinkClosed()),
        isA<LanEnded>().having((e) => e.linkOpen, 'linkOpen', isFalse),
      );
    });

    test('an error while connecting fails instead of spinning', () {
      final s = reduceLan(
        const LanConnecting(LanRole.join),
        const LanError('incompatible protocol version'),
      );
      expect(s, isA<LanFailed>());
      expect(LanGameState(session: s).waiting, isFalse);
    });

    test('spectators never get draw offers', () {
      const s = LanLive(spectator: true);
      expect(reduceLan(s, const LanDrawOffered()), same(s));
    });

    test('leave always returns to idle', () {
      expect(
        reduceLan(const LanLive(spectator: false), const LanLeft()),
        isA<LanIdle>(),
      );
    });

    test('recognises a refused local move', () {
      expect(
        rejectedLocalMove('rejected local move out of turn: e2e4'),
        'e2e4',
      );
      expect(
        rejectedLocalMove('rejected local move out of turn or illegal: a7a8q'),
        'a7a8q',
      );
      expect(rejectedLocalMove('incompatible protocol version'), isNull);
      expect(isIncompatibleVersion('incompatible protocol version'), isTrue);
    });

    test('host-side version mismatch notice maps to the update message', () {
      final t = AppLocalizationsEn();
      expect(isVersionMismatchNotice('version_mismatch:9'), isTrue);
      expect(
        isVersionMismatchNotice('rejected local move out of turn'),
        isFalse,
      );
      expect(
        localizeLanError(t, 'version_mismatch:9'),
        t.lanIncompatibleVersion,
      );
      expect(
        localizeMatchError(t, 'version_mismatch:9'),
        t.lanIncompatibleVersion,
      );
    });

    test('chat is capped and bounded', () {
      var chat = <ChatMessage>[];
      for (var i = 0; i < maxChatLines + 50; i++) {
        chat = appendChat(chat, ChatMessage('$i', false));
      }
      expect(chat, hasLength(maxChatLines));
      expect(chat.last.text, '${maxChatLines + 49}');
      expect(chatTextAllowed('😀' * 300), isFalse); // 600 UTF-16 units
      expect(chatTextAllowed('hi'), isTrue);
    });
  });

  group('multi-board session', () {
    test('lobby to match to result; a later disconnect keeps the result', () {
      var s = reduceMultiBoard(const MbIdle(), const MbOpened());
      expect(matchStarted(s), isFalse);
      s = reduceMultiBoard(s, const MbStarted());
      expect(matchStarted(s), isTrue);
      s = reduceMultiBoard(s, const MbResult());
      expect(reduceMultiBoard(s, const MbLinkClosed()), isA<MbFinished>());
    });

    test('a disconnect mid-match is a visible lost state', () {
      final s = reduceMultiBoard(const MbPlaying(), const MbLinkClosed());
      expect(s, isA<MbLost>());
      expect(matchStarted(s), isTrue);
      expect(
        matchStarted(reduceMultiBoard(const MbLobby(), const MbLinkClosed())),
        isFalse,
      );
    });
  });

  group('analysis job', () {
    const move = AnalysisMove(
      ply: 1,
      uci: 'e2e4',
      san: 'e4',
      evalCp: 20,
      mateIn: 0,
      evalBeforeCp: 20,
      mateBeforeIn: 0,
      bestUci: 'e2e4',
      bestSan: 'e4',
      cpLoss: 0,
      classification: 'best',
    );

    test('runs, records plies and finishes', () {
      var s = reduceAnalysis(const AnalysisState(), const AnalysisStarted(2));
      expect(s.running, isTrue);
      s = reduceAnalysis(s, const AnalysisPly(move, 1, 2));
      expect(s.progress, 1);
      s = reduceAnalysis(
        s,
        const AnalysisFinished(whiteAccuracy: 90, blackAccuracy: 80),
      );
      expect(s.done, isTrue);
      expect(s.moves, hasLength(1));
    });

    test('an error is a visible state, not "preparing" forever', () {
      var s = reduceAnalysis(const AnalysisState(), const AnalysisStarted(2));
      s = reduceAnalysis(s, const AnalysisErrored('invalid FEN'));
      expect(s.job, isA<AnalysisFailed>());
      // A late close after the result does not turn it into a failure.
      final done = reduceAnalysis(
        reduceAnalysis(const AnalysisState(), const AnalysisStarted(0)),
        const AnalysisFinished(whiteAccuracy: 0, blackAccuracy: 0),
      );
      expect(
        reduceAnalysis(done, const AnalysisErrored('')).job,
        isA<AnalysisDone>(),
      );
    });

    test('a new start clears the previous result', () {
      final s = reduceAnalysis(
        const AnalysisState(job: AnalysisDone(), moves: [move]),
        const AnalysisStarted(3),
      );
      expect(s.moves, isEmpty);
      expect(s.running, isTrue);
    });
  });
}

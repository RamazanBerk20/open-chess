import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/rust/api/net.dart';
import 'package:open_chess/src/state/ai_provider.dart';
import 'package:open_chess/src/state/clock_provider.dart';
import 'package:open_chess/src/state/l10n_labels.dart';
import 'package:open_chess/src/state/game_mode.dart';
import 'package:open_chess/src/state/game_providers.dart';
import 'package:open_chess/src/state/lan_profile.dart';
import 'package:open_chess/src/state/player_profile.dart';
import 'package:open_chess/src/state/time_control.dart';

/// A single chat line. [mine] is true for messages this device sent.
class ChatMessage {
  final String text;
  final bool mine;
  final String? senderName;
  const ChatMessage(this.text, this.mine, {this.senderName});
}

/// Keep at most this many chat lines per list (a flooding peer cannot grow
/// memory or per-message copy cost without bound).
const maxChatLines = 200;

List<ChatMessage> appendChat(List<ChatMessage> list, ChatMessage m) {
  final next = [...list, m];
  return next.length > maxChatLines
      ? next.sublist(next.length - maxChatLines)
      : next;
}

enum LanRole { host, join, spectate }

/// Two-player LAN session lifecycle.
sealed class LanSession {
  const LanSession();
}

class LanIdle extends LanSession {
  const LanIdle();
}

class LanConnecting extends LanSession {
  final LanRole role;
  const LanConnecting(this.role);
}

class LanLive extends LanSession {
  final bool spectator;
  final bool drawOfferIncoming;
  const LanLive({required this.spectator, this.drawOfferIncoming = false});
}

/// The match result is final. [linkOpen] while the socket still carries chat.
class LanEnded extends LanSession {
  final bool linkOpen;
  const LanEnded({required this.linkOpen});
}

class LanFailed extends LanSession {
  final String error;
  const LanFailed(this.error);
}

sealed class LanEvent {
  const LanEvent();
}

class LanStart extends LanEvent {
  final LanRole role;
  const LanStart(this.role);
}

class LanConnected extends LanEvent {
  final bool spectator;
  const LanConnected({required this.spectator});
}

class LanDrawOffered extends LanEvent {
  const LanDrawOffered();
}

class LanDrawAnswered extends LanEvent {
  const LanDrawAnswered();
}

/// Resignation, agreed draw, timeout, or board result.
class LanMatchEnded extends LanEvent {
  const LanMatchEnded();
}

class LanLinkClosed extends LanEvent {
  const LanLinkClosed();
}

class LanError extends LanEvent {
  final String error;
  const LanError(this.error);
}

class LanLeft extends LanEvent {
  const LanLeft();
}

/// Pure transition. An ended match is terminal: offers and late events after
/// it change nothing except closing the link.
LanSession reduceLan(LanSession s, LanEvent e) => switch ((s, e)) {
  (_, LanLeft()) => const LanIdle(),
  (_, LanStart(:final role)) => LanConnecting(role),
  (LanConnecting(), LanConnected(:final spectator)) => LanLive(
    spectator: spectator,
  ),
  (LanConnecting(), LanError(:final error)) => LanFailed(error),
  (LanConnecting(), LanLinkClosed()) => const LanFailed(''),
  (LanLive(spectator: false), LanDrawOffered()) => const LanLive(
    spectator: false,
    drawOfferIncoming: true,
  ),
  (LanLive(:final spectator), LanDrawAnswered()) => LanLive(
    spectator: spectator,
  ),
  (LanLive(), LanMatchEnded()) => const LanEnded(linkOpen: true),
  (LanLive(), LanLinkClosed()) => const LanEnded(linkOpen: false),
  (LanEnded(), LanLinkClosed()) => const LanEnded(linkOpen: false),
  _ => s,
};

class LanGameState {
  final LanSession session;
  final String myName;
  final String opponentName;
  final bool youAreWhite;
  final bool isSpectator; // role, kept after the match ends (chat routing)
  final PlayerProfile whiteProfile;
  final PlayerProfile blackProfile;
  final int spectatorCount;
  final List<ChatMessage> chat;
  final List<ChatMessage> spectatorChat;

  /// Last transport error to surface (a snackbar); does not change the phase
  /// once live.
  final String? error;

  const LanGameState({
    this.session = const LanIdle(),
    this.myName = '',
    this.opponentName = '',
    this.youAreWhite = true,
    this.isSpectator = false,
    this.whiteProfile = const PlayerProfile(),
    this.blackProfile = const PlayerProfile(),
    this.spectatorCount = 0,
    this.chat = const [],
    this.spectatorChat = const [],
    this.error,
  });

  bool get waiting => session is LanConnecting;
  bool get connected => switch (session) {
    LanLive() => true,
    LanEnded(:final linkOpen) => linkOpen,
    _ => false,
  };
  bool get ended => session is LanEnded;
  bool get drawOfferIncoming => switch (session) {
    LanLive(:final drawOfferIncoming) => drawOfferIncoming,
    _ => false,
  };

  LanGameState copyWith({
    LanSession? session,
    String? myName,
    String? opponentName,
    bool? youAreWhite,
    bool? isSpectator,
    PlayerProfile? whiteProfile,
    PlayerProfile? blackProfile,
    int? spectatorCount,
    List<ChatMessage>? chat,
    List<ChatMessage>? spectatorChat,
    String? error,
  }) => LanGameState(
    session: session ?? this.session,
    myName: myName ?? this.myName,
    opponentName: opponentName ?? this.opponentName,
    youAreWhite: youAreWhite ?? this.youAreWhite,
    isSpectator: isSpectator ?? this.isSpectator,
    whiteProfile: whiteProfile ?? this.whiteProfile,
    blackProfile: blackProfile ?? this.blackProfile,
    spectatorCount: spectatorCount ?? this.spectatorCount,
    chat: chat ?? this.chat,
    spectatorChat: spectatorChat ?? this.spectatorChat,
    error: error,
  );
}

/// The UCI of a local move the host refused (`rejected local move …: <uci>`),
/// or null for any other error text.
String? rejectedLocalMove(String error) {
  final m = RegExp(r'^rejected local move [^:]*: (\S+)$').firstMatch(error);
  return m?.group(1);
}

/// Chat limits shared with the Rust side (UTF-16 units and UTF-8 bytes).
bool chatTextAllowed(String t) =>
    t.isNotEmpty && t.length <= 512 && utf8.encode(t).length <= 2048;

final lanProvider = NotifierProvider<LanController, LanGameState>(
  LanController.new,
);

/// A closed socket ends a live LAN game, but must never replace a completed
/// result or affect a local game which has already replaced the LAN board.
bool shouldApplyLanDisconnect({
  required bool connected,
  required bool matchEnded,
  required bool gameIsOver,
  required bool activeLanGame,
}) => connected && !matchEnded && !gameIsOver && activeLanGame;

/// Whether this provider still owns a pending, live, or just-finished LAN
/// session that must be released before starting a local game.
bool hasActiveLanSession(LanGameState state) => state.session is! LanIdle;

class LanController extends Notifier<LanGameState> {
  StreamSubscription<NetEvent>? _sub;
  int _eventEpoch = 0;

  @override
  LanGameState build() {
    // A local/AI setup can replace the game mode before the prior game route
    // disposes. End its transport immediately instead of leaving old network
    // events attached to the new board.
    ref.listen<GameMode>(gameModeProvider, (previous, next) {
      if (previous?.lan == true && !next.lan) leave();
    });
    ref.onDispose(() {
      _invalidateEventStream();
      netLeave();
    });
    return const LanGameState();
  }

  void host(
    PlayerProfile profile,
    int baseMinutes,
    int incrementSeconds,
    bool hostWhite,
    GameVariant variant,
    int chess960Index,
    bool allowSpectators,
  ) {
    _listen(
      netHost(
        profile: lanProfileWire(profile),
        baseMinutes: baseMinutes,
        incrementSeconds: incrementSeconds,
        hostWhite: hostWhite,
        variant: variantCode(variant),
        chess960Index: chess960Index,
        allowSpectators: allowSpectators,
      ),
      profile,
      LanRole.host,
    );
  }

  void join(String addr, PlayerProfile profile) {
    _listen(
      netJoin(addr: addr, profile: lanProfileWire(profile)),
      profile,
      LanRole.join,
    );
  }

  void spectate(String addr, PlayerProfile profile) {
    _listen(
      netSpectate(addr: addr, profile: lanProfileWire(profile)),
      profile,
      LanRole.spectate,
    );
  }

  void _dispatch(LanEvent e) =>
      state = state.copyWith(session: reduceLan(state.session, e));

  void _listen(Stream<NetEvent> stream, PlayerProfile profile, LanRole role) {
    // Invalidate any local engine request before this global game controller
    // becomes a network mirror.
    ref.read(aiControllerProvider.notifier).cancel();
    _invalidateEventStream();
    final epoch = _eventEpoch;
    state = LanGameState(
      session: LanConnecting(role),
      myName: profile.username,
    );
    _sub = stream.listen(
      (event) {
        if (epoch == _eventEpoch) _onEvent(event);
      },
      onError: (e) {
        if (epoch == _eventEpoch) {
          _dispatch(LanError('$e'));
          state = state.copyWith(error: '$e');
        }
      },
    );
  }

  void _invalidateEventStream() {
    _eventEpoch++;
    _sub?.cancel();
    _sub = null;
  }

  void _markMatchEnded() => _dispatch(const LanMatchEnded());

  void _onEvent(NetEvent e) {
    final mode = ref.read(gameModeProvider);
    // The provider remains alive across every game screen. Once a local game
    // replaces a LAN game, no queued network event may touch that local board.
    if (e.kind != NetEventKind.connected && state.connected && !mode.lan) {
      return;
    }
    final game = ref.read(gameControllerProvider.notifier);
    switch (e.kind) {
      case NetEventKind.connected:
        final isSpectator = e.isSpectator;
        final myColor = e.youAreWhite ? PieceColor.white : PieceColor.black;
        if (isSpectator) {
          ref.read(gameModeProvider.notifier).setLanSpectator();
        } else {
          ref.read(gameModeProvider.notifier).setLan(myColor);
        }
        final tc = e.baseMinutes == 0
            ? TimeControlOption.infinite
            : TimeControlOption(
                '${e.baseMinutes}+${e.incrementSeconds}',
                e.baseMinutes,
                e.incrementSeconds,
              );
        ref.read(selectedTimeControlProvider.notifier).set(tc);
        final variant = variantFromCode(e.variant);
        // A live spectator starts from the host's current FEN; a playing peer
        // keeps the normal startup path so its full local history is intact.
        ref
            .read(customStartFenProvider.notifier)
            .set(isSpectator || variant == GameVariant.chess960 ? e.fen : null);
        ref.read(selectedVariantProvider.notifier).set(variant);
        ref.invalidate(gameControllerProvider);
        if (isSpectator) {
          ref
              .read(gameControllerProvider.notifier)
              .lanLoadSnapshot(
                fen: e.fen,
                variant: variant,
                baseMinutes: e.baseMinutes,
                incrementSeconds: e.incrementSeconds,
                whiteMs: e.whiteMs,
                blackMs: e.blackMs,
                whiteChecks: e.whiteChecks,
                blackChecks: e.blackChecks,
                whiteHand: e.whiteHand,
                blackHand: e.blackHand,
                promoted: e.promoted,
              );
        }
        ref.invalidate(clockProvider);
        _dispatch(LanConnected(spectator: isSpectator));
        state = state.copyWith(
          isSpectator: isSpectator,
          youAreWhite: e.youAreWhite,
          opponentName: isSpectator
              ? '${e.whiteName} vs ${e.blackName}'
              : e.youAreWhite
              ? e.blackName
              : e.whiteName,
          whiteProfile: lanProfileFromWire(e.whiteProfile),
          blackProfile: lanProfileFromWire(e.blackProfile),
        );
      case NetEventKind.move:
        game.lanApplyRemote(e.uci, e.whiteMs, e.blackMs);
      case NetEventKind.resign:
        switch (e.text) {
          case 'timeout:white':
            game.lanApplyTimeout(PieceColor.white);
          case 'timeout:black':
            game.lanApplyTimeout(PieceColor.black);
          case LanResultCode.gameWhiteWins ||
              LanResultCode.gameBlackWins ||
              LanResultCode.gameStalemate ||
              LanResultCode.gameDrawFifty ||
              LanResultCode.gameDrawThreefold ||
              LanResultCode.gameDrawInsufficient:
            game.lanSetResult(e.text);
          default:
            game.lanSetResult(LanResultCode.opponentResigned);
        }
        _markMatchEnded();
      case NetEventKind.drawOffer:
        _dispatch(const LanDrawOffered()); // ignored after the match ended
      case NetEventKind.drawResponse:
        if (e.drawAccepted) {
          game.lanSetResult(LanResultCode.drawAgreed);
          _markMatchEnded();
        }
      case NetEventKind.chat:
        if (!state.isSpectator) {
          state = state.copyWith(
            chat: appendChat(state.chat, ChatMessage(e.text, false)),
          );
        }
      case NetEventKind.spectatorChat:
        if (state.isSpectator) {
          state = state.copyWith(
            spectatorChat: appendChat(
              state.spectatorChat,
              ChatMessage(e.text, false, senderName: e.sender),
            ),
          );
        }
      case NetEventKind.disconnected:
        final currentGame = ref.read(gameControllerProvider);
        final currentMode = ref.read(gameModeProvider);
        if (shouldApplyLanDisconnect(
          connected: state.connected,
          matchEnded: state.ended,
          gameIsOver: currentGame.isOver,
          activeLanGame: currentMode.lan,
        )) {
          game.lanSetResult(
            isIncompatibleVersion(e.text)
                ? LanResultCode.incompatibleVersion
                : LanResultCode.opponentDisconnected,
          );
        }
        _dispatch(const LanLinkClosed());
      case NetEventKind.error:
        if (isVersionMismatchNotice(e.text)) {
          state = state.copyWith(error: e.text); // lobby stays open
          return;
        }
        // The host refused one of our moves (out of turn / after the end):
        // non-fatal. Take the optimistic local ply back so both boards agree.
        final rejected = rejectedLocalMove(e.text);
        if (rejected != null) game.lanRevertLocal(rejected);
        _dispatch(LanError(e.text));
        state = state.copyWith(error: e.text);
      case NetEventKind.spectatorJoined:
        state = state.copyWith(spectatorCount: state.spectatorCount + 1);
      default:
        break; // Bughouse events are handled by the Bughouse LAN controller.
    }
  }

  bool get _live => state.session is LanLive;

  void resign() {
    if (state.isSpectator || !_live) return;
    netResign();
    ref
        .read(gameControllerProvider.notifier)
        .lanSetResult(LanResultCode.youResigned);
    _markMatchEnded();
  }

  void offerDraw() {
    if (!state.isSpectator && _live) netOfferDraw();
  }

  /// Returns false (and sends nothing) when the message is empty or too long,
  /// so the caller can keep the text in the input.
  bool sendChat(String text) {
    final t = text.trim();
    if (!chatTextAllowed(t)) return false;
    if (state.isSpectator) {
      netSendSpectatorChat(text: t);
      state = state.copyWith(
        spectatorChat: appendChat(
          state.spectatorChat,
          ChatMessage(t, true, senderName: state.myName),
        ),
      );
    } else {
      netSendChat(text: t);
      state = state.copyWith(
        chat: appendChat(state.chat, ChatMessage(t, true)),
      );
    }
    return true;
  }

  void respondDraw(bool accept) {
    // A late answer after the game ended must not overwrite the real result.
    if (state.isSpectator ||
        !state.drawOfferIncoming ||
        ref.read(gameControllerProvider).isOver) {
      return;
    }
    netRespondDraw(accept: accept);
    _dispatch(const LanDrawAnswered());
    if (accept) {
      ref
          .read(gameControllerProvider.notifier)
          .lanSetResult(LanResultCode.drawAgreed);
      _markMatchEnded();
    }
  }

  void leave() {
    final hadSession = _sub != null || hasActiveLanSession(state);
    _invalidateEventStream();
    state = LanGameState(session: reduceLan(state.session, const LanLeft()));
    if (hadSession) netLeave();
  }
}

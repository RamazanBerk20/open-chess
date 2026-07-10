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

class LanGameState {
  final bool waiting; // hosting/connecting, not yet connected
  final bool connected;
  final bool ended; // chess result resolved or the transport has ended
  final String myName;
  final String opponentName;
  final bool youAreWhite;
  final bool isSpectator;
  final bool drawOfferIncoming;
  final PlayerProfile whiteProfile;
  final PlayerProfile blackProfile;
  final int spectatorCount;
  final List<ChatMessage> chat;
  final List<ChatMessage> spectatorChat;
  final String? error;

  const LanGameState({
    this.waiting = false,
    this.connected = false,
    this.ended = false,
    this.myName = '',
    this.opponentName = '',
    this.youAreWhite = true,
    this.isSpectator = false,
    this.drawOfferIncoming = false,
    this.whiteProfile = const PlayerProfile(),
    this.blackProfile = const PlayerProfile(),
    this.spectatorCount = 0,
    this.chat = const [],
    this.spectatorChat = const [],
    this.error,
  });

  LanGameState copyWith({
    bool? waiting,
    bool? connected,
    bool? ended,
    String? myName,
    String? opponentName,
    bool? youAreWhite,
    bool? isSpectator,
    bool? drawOfferIncoming,
    PlayerProfile? whiteProfile,
    PlayerProfile? blackProfile,
    int? spectatorCount,
    List<ChatMessage>? chat,
    List<ChatMessage>? spectatorChat,
    String? error,
  }) => LanGameState(
    waiting: waiting ?? this.waiting,
    connected: connected ?? this.connected,
    ended: ended ?? this.ended,
    myName: myName ?? this.myName,
    opponentName: opponentName ?? this.opponentName,
    youAreWhite: youAreWhite ?? this.youAreWhite,
    isSpectator: isSpectator ?? this.isSpectator,
    drawOfferIncoming: drawOfferIncoming ?? this.drawOfferIncoming,
    whiteProfile: whiteProfile ?? this.whiteProfile,
    blackProfile: blackProfile ?? this.blackProfile,
    spectatorCount: spectatorCount ?? this.spectatorCount,
    chat: chat ?? this.chat,
    spectatorChat: spectatorChat ?? this.spectatorChat,
    error: error,
  );
}

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
bool hasActiveLanSession(LanGameState state) =>
    state.waiting || state.connected || state.ended;

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
    );
  }

  void join(String addr, PlayerProfile profile) {
    _listen(netJoin(addr: addr, profile: lanProfileWire(profile)), profile);
  }

  void spectate(String addr, PlayerProfile profile) {
    _listen(netSpectate(addr: addr, profile: lanProfileWire(profile)), profile);
  }

  void _listen(Stream<NetEvent> stream, PlayerProfile profile) {
    // Invalidate any local engine request before this global game controller
    // becomes a network mirror.
    ref.read(aiControllerProvider.notifier).cancel();
    _invalidateEventStream();
    final epoch = _eventEpoch;
    state = LanGameState(waiting: true, myName: profile.username);
    _sub = stream.listen(
      (event) {
        if (epoch == _eventEpoch) _onEvent(event);
      },
      onError: (e) {
        if (epoch == _eventEpoch) {
          state = state.copyWith(error: '$e', waiting: false);
        }
      },
    );
  }

  void _invalidateEventStream() {
    _eventEpoch++;
    _sub?.cancel();
    _sub = null;
  }

  void _markMatchEnded() {
    state = state.copyWith(ended: true, drawOfferIncoming: false);
  }

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
        state = state.copyWith(
          waiting: false,
          connected: true,
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
        if (!state.isSpectator) {
          state = state.copyWith(drawOfferIncoming: true);
        }
      case NetEventKind.drawResponse:
        if (e.drawAccepted) {
          game.lanSetResult(LanResultCode.drawAgreed);
          _markMatchEnded();
        }
      case NetEventKind.chat:
        if (!state.isSpectator) {
          state = state.copyWith(
            chat: [...state.chat, ChatMessage(e.text, false)],
          );
        }
      case NetEventKind.spectatorChat:
        if (state.isSpectator) {
          state = state.copyWith(
            spectatorChat: [
              ...state.spectatorChat,
              ChatMessage(e.text, false, senderName: e.sender),
            ],
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
            e.text.isEmpty ? LanResultCode.opponentDisconnected : e.text,
          );
        }
        state = state.copyWith(
          ended: true,
          connected: false,
          waiting: false,
          drawOfferIncoming: false,
        );
      case NetEventKind.error:
        state = state.copyWith(error: e.text);
      case NetEventKind.spectatorJoined:
        state = state.copyWith(spectatorCount: state.spectatorCount + 1);
      default:
        break; // Bughouse events are handled by the Bughouse LAN controller.
    }
  }

  void resign() {
    if (state.isSpectator) return;
    netResign();
    ref
        .read(gameControllerProvider.notifier)
        .lanSetResult(LanResultCode.youResigned);
    _markMatchEnded();
  }

  void offerDraw() {
    if (!state.isSpectator) netOfferDraw();
  }

  void sendChat(String text) {
    final t = text.trim();
    if (t.isEmpty || t.length > 512 || utf8.encode(t).length > 2048) return;
    if (state.isSpectator) {
      netSendSpectatorChat(text: t);
      state = state.copyWith(
        spectatorChat: [
          ...state.spectatorChat,
          ChatMessage(t, true, senderName: state.myName),
        ],
      );
    } else {
      netSendChat(text: t);
      state = state.copyWith(chat: [...state.chat, ChatMessage(t, true)]);
    }
  }

  void respondDraw(bool accept) {
    if (state.isSpectator) return;
    netRespondDraw(accept: accept);
    state = state.copyWith(drawOfferIncoming: false);
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
    state = const LanGameState();
    if (hadSession) netLeave();
  }
}

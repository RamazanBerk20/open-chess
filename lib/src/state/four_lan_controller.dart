import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/src/rust/api/net.dart';
import 'package:open_chess/src/state/four_player_controller.dart';
import 'package:open_chess/src/state/l10n_labels.dart';
import 'package:open_chess/src/state/lan_controller.dart' show maxChatLines;
import 'package:open_chess/src/state/lan_profile.dart';
import 'package:open_chess/src/state/multi_board_session.dart';
import 'package:open_chess/src/state/multicast_lock.dart';
import 'package:open_chess/src/state/player_profile.dart';

/// Wire values for four-player LAN seat assignments.
///
/// Host and joined players each occupy exactly one color. Any remaining
/// colors can be delegated to the host authority's built-in AI.
const int fourLanHostSeatOwner = -1;
const int fourLanAiSeatOwner = -2;
const int fourLanNoAiDifficulty = -1;
const int fourLanDefaultAiDifficulty = defaultFourAiDifficultyCode;
const int fourLanAiDifficultyCount = fourAiDifficultyCodeCount;

/// A private message carried only over a four-player spectator transport.
class FourSpectatorChatMessage {
  final String text;
  final bool mine;
  final String? senderName;

  const FourSpectatorChatMessage(this.text, this.mine, {this.senderName});
}

/// Mirrors the bounded spectator-chat protocol before an outbound message is
/// sent over the native bridge.
bool isValidFourSpectatorChat(String text) {
  final message = text.trim();
  return message.isNotEmpty &&
      message.length <= 512 &&
      utf8.encode(message).length <= 2048;
}

/// Checks a host-provided four-player LAN seat assignment before it crosses
/// the bridge. This mirrors the network authority: every connected human owns
/// exactly one color and AI may own any remaining colors.
bool isValidFourLanSeatAssignment(List<int> seatOwners, int joinerCount) {
  if (seatOwners.length != 4 || joinerCount < 0 || joinerCount > 3) {
    return false;
  }

  final requiredHumans = <int>{
    fourLanHostSeatOwner,
    for (var joiner = 0; joiner < joinerCount; joiner++) joiner,
  };
  for (final owner in seatOwners) {
    if (owner == fourLanAiSeatOwner) continue;
    if (!requiredHumans.remove(owner)) return false;
  }
  return requiredHumans.isEmpty;
}

/// Validates the host's per-color AI difficulty choices. Human-owned colors
/// must use the sentinel; every AI-owned color maps to one fixed preset code.
bool isValidFourLanAiDifficulties(
  List<int> seatOwners,
  List<int> aiDifficulties,
) {
  if (seatOwners.length != 4 || aiDifficulties.length != 4) return false;
  for (var seat = 0; seat < 4; seat++) {
    final difficulty = aiDifficulties[seat];
    if (seatOwners[seat] == fourLanAiSeatOwner) {
      if (difficulty < 0 || difficulty >= fourLanAiDifficultyCount) {
        return false;
      }
    } else if (difficulty != fourLanNoAiDifficulty) {
      return false;
    }
  }
  return true;
}

/// One complete four-player LAN seat assignment. AI difficulty belongs to its
/// assigned AI seat, so both values must be moved together when colors are
/// randomized.
class FourLanSeatAssignment {
  final List<int> seatOwners;
  final List<int> aiDifficulties;

  const FourLanSeatAssignment({
    required this.seatOwners,
    required this.aiDifficulties,
  });
}

/// The complete default assignment for the current lobby. It is useful before
/// the host has manually placed a newly joined player, and gives Random a
/// valid source to shuffle immediately.
FourLanSeatAssignment defaultFourLanSeatAssignment(int joinerCount) {
  if (joinerCount < 0 || joinerCount > 3) {
    throw ArgumentError.value(joinerCount, 'joinerCount', 'Expected 0..3');
  }
  final humans = <int>[
    fourLanHostSeatOwner,
    for (var joiner = 0; joiner < joinerCount; joiner++) joiner,
  ];
  return FourLanSeatAssignment(
    seatOwners: [
      ...humans,
      for (var seat = humans.length; seat < 4; seat++) fourLanAiSeatOwner,
    ],
    aiDifficulties: [
      for (var seat = 0; seat < humans.length; seat++) fourLanNoAiDifficulty,
      for (var seat = humans.length; seat < 4; seat++)
        fourLanDefaultAiDifficulty,
    ],
  );
}

/// Randomly assigns colors to the current host, joined players, and host-run
/// AI seats. The input is left unchanged and every owner/difficulty pair stays
/// intact, which preserves the authority's assignment contract.
FourLanSeatAssignment randomizeFourLanSeatAssignment(
  List<int> seatOwners,
  List<int> aiDifficulties, {
  required int joinerCount,
  Random? random,
}) {
  if (!isValidFourLanSeatAssignment(seatOwners, joinerCount) ||
      !isValidFourLanAiDifficulties(seatOwners, aiDifficulties)) {
    throw ArgumentError('Expected a valid four-player LAN assignment.');
  }

  final pairs = List<({int owner, int difficulty})>.generate(
    4,
    (seat) => (owner: seatOwners[seat], difficulty: aiDifficulties[seat]),
  );
  final original = List<({int owner, int difficulty})>.of(pairs);
  pairs.shuffle(random);

  // A no-op shuffle is technically valid but makes the control look broken.
  // There is always at least the unique host pair, so rotating is safe.
  if (_sameFourLanSeatPairs(pairs, original)) {
    pairs.add(pairs.removeAt(0));
  }

  return FourLanSeatAssignment(
    seatOwners: [for (final pair in pairs) pair.owner],
    aiDifficulties: [for (final pair in pairs) pair.difficulty],
  );
}

bool _sameFourLanSeatPairs(
  List<({int owner, int difficulty})> left,
  List<({int owner, int difficulty})> right,
) {
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

class FourLanState {
  final MultiBoardSession session;
  final bool isHost;
  final bool isSpectator;
  final String myName;
  final List<String> joiners;
  final List<PlayerProfile> joinerProfiles;
  final List<int> mySeats;
  final List<String> seatNames;
  final List<PlayerProfile> seatProfiles;
  final String format; // "ffa" | "teams"
  final List<FourSpectatorChatMessage> spectatorChat;
  final String? error;

  const FourLanState({
    this.session = const MbIdle(),
    this.isHost = false,
    this.isSpectator = false,
    this.myName = '',
    this.joiners = const [],
    this.joinerProfiles = const [],
    this.mySeats = const [],
    this.seatNames = const [],
    this.seatProfiles = const [],
    this.format = 'ffa',
    this.spectatorChat = const [],
    this.error,
  });

  bool get active => session is! MbIdle;
  bool get started => matchStarted(session);

  FourLanState copyWith({
    MultiBoardSession? session,
    bool? isHost,
    bool? isSpectator,
    String? myName,
    List<String>? joiners,
    List<PlayerProfile>? joinerProfiles,
    List<int>? mySeats,
    List<String>? seatNames,
    List<PlayerProfile>? seatProfiles,
    String? format,
    List<FourSpectatorChatMessage>? spectatorChat,
    String? error,
  }) => FourLanState(
    session: session ?? this.session,
    isHost: isHost ?? this.isHost,
    isSpectator: isSpectator ?? this.isSpectator,
    myName: myName ?? this.myName,
    joiners: joiners ?? this.joiners,
    joinerProfiles: joinerProfiles ?? this.joinerProfiles,
    mySeats: mySeats ?? this.mySeats,
    seatNames: seatNames ?? this.seatNames,
    seatProfiles: seatProfiles ?? this.seatProfiles,
    format: format ?? this.format,
    spectatorChat: spectatorChat ?? this.spectatorChat,
    error: error,
  );
}

final fourLanProvider = NotifierProvider<FourLanController, FourLanState>(
  FourLanController.new,
);

class FourLanController extends Notifier<FourLanState> {
  StreamSubscription<NetEvent>? _sub;
  FourPlayerController? _match;
  final List<NetEvent> _pendingMatchEvents = <NetEvent>[];
  // A spectator can receive an entire ongoing match before the route mounts.
  // Rust replays up to 4096 moves, and one live move can arrive before the
  // route finishes mounting.
  static const int _maxPendingMatchEvents = 4097;
  NetEvent? _pendingTerminalEvent;

  @override
  FourLanState build() {
    ref.onDispose(() {
      _sub?.cancel();
      netLeave();
    });
    return const FourLanState();
  }

  bool _advertising = false; // multicast lock held while the lobby is open

  void _stopAdvertising() {
    if (_advertising) releaseMulticast();
    _advertising = false;
  }

  void host(
    PlayerProfile profile,
    String format, {
    required bool allowSpectators,
  }) {
    _stopAdvertising();
    acquireMulticast();
    _advertising = true;
    _listen(
      netHostFour(
        profile: lanProfileWire(profile),
        format: format,
        allowSpectators: allowSpectators,
      ),
      isHost: true,
      format: format,
      profile: profile,
    );
  }

  void join(String addr, PlayerProfile profile) {
    _listen(
      netJoinFour(addr: addr, profile: lanProfileWire(profile)),
      isHost: false,
      format: 'ffa',
      profile: profile,
    );
  }

  /// Joins a live four-player host as a read-only spectator. The Rust
  /// authority replays its current move history before live broadcasts begin.
  void spectate(String addr, PlayerProfile profile) {
    _listen(
      netSpectateFour(addr: addr, profile: lanProfileWire(profile)),
      isHost: false,
      isSpectator: true,
      format: 'ffa',
      profile: profile,
    );
  }

  void _listen(
    Stream<NetEvent> stream, {
    required bool isHost,
    required PlayerProfile profile,
    required String format,
    bool isSpectator = false,
  }) {
    _sub?.cancel();
    _match = null;
    _pendingMatchEvents.clear();
    _pendingTerminalEvent = null;
    state = FourLanState(
      session: const MbLobby(),
      isHost: isHost,
      isSpectator: isSpectator,
      myName: profile.username,
      format: format,
    );
    _sub = stream.listen(
      _onEvent,
      onError: (e) => state = state.copyWith(error: '$e'),
    );
  }

  void startAssign(List<int> seatOwners, List<int> aiDifficulties) {
    if (!state.isHost ||
        !isValidFourLanSeatAssignment(seatOwners, state.joiners.length) ||
        !isValidFourLanAiDifficulties(seatOwners, aiDifficulties)) {
      return;
    }
    netFourStart(seatOwner: seatOwners, aiDifficulties: aiDifficulties);
  }

  void register(FourPlayerController match) {
    _match = match;
    for (final event in _pendingMatchEvents) {
      _applyToMatch(event);
    }
    _pendingMatchEvents.clear();
    final terminal = _pendingTerminalEvent;
    _pendingTerminalEvent = null;
    if (terminal != null) _applyToMatch(terminal);
  }

  /// Detach a route-owned controller before it is disposed. The connection can
  /// outlive a screen transition, but it must not call a stale notifier.
  void unregister(FourPlayerController match) {
    if (identical(_match, match)) _match = null;
  }

  void _onEvent(NetEvent e) {
    switch (e.kind) {
      case NetEventKind.fourJoin:
        final profile = lanProfileFromWire(e.peerProfile);
        state = state.copyWith(
          joiners: [...state.joiners, profile.username],
          joinerProfiles: [...state.joinerProfiles, profile],
        );
      case NetEventKind.fourStart:
        _stopAdvertising();
        state = state.copyWith(
          session: reduceMultiBoard(state.session, const MbStarted()),
          isSpectator: state.isSpectator || e.isSpectator,
          mySeats: e.yourSeats.map((x) => x.toInt()).toList(),
          seatNames: e.seats,
          seatProfiles: e.seatProfiles.map(lanProfileFromWire).toList(),
          format: e.variant.isEmpty ? state.format : e.variant,
        );
      case NetEventKind.fourMove:
        _applyOrQueue(e);
      case NetEventKind.fourResult:
        state = state.copyWith(
          session: reduceMultiBoard(state.session, const MbResult()),
        );
        _applyOrQueue(e);
      case NetEventKind.disconnected:
        state = state.copyWith(
          session: reduceMultiBoard(state.session, const MbLinkClosed()),
          error: e.text.isEmpty ? LanResultCode.opponentDisconnected : e.text,
        );
        _applyOrQueue(e);
      case NetEventKind.spectatorChat:
        if (state.isSpectator) {
          state = state.copyWith(
            spectatorChat: _capped([
              ...state.spectatorChat,
              FourSpectatorChatMessage(e.text, false, senderName: e.sender),
            ]),
          );
        }
      case NetEventKind.error:
        state = state.copyWith(error: e.text);
      default:
        break;
    }
  }

  void _applyOrQueue(NetEvent event) {
    if (_match != null) {
      _applyToMatch(event);
      return;
    }
    if (_pendingMatchEvents.length >= _maxPendingMatchEvents) {
      if (event.kind == NetEventKind.fourResult ||
          event.kind == NetEventKind.disconnected) {
        // Do not lose the terminal state if an exact-limit spectator replay
        // is followed by a result/disconnect before the route mounts.
        _pendingTerminalEvent ??= event;
        return;
      }
      state = state.copyWith(error: tooManyPendingUpdates);
      return;
    }
    _pendingMatchEvents.add(event);
  }

  void _applyToMatch(NetEvent event) {
    final match = _match;
    if (match == null) return;
    switch (event.kind) {
      case NetEventKind.fourMove:
        match.applyRemoteMove(event.seat.toInt(), event.uci);
      case NetEventKind.fourResult:
        match.applyResult(event.text);
      case NetEventKind.disconnected:
        match.markConnectionLost();
      default:
        break;
    }
  }

  /// Spectator chat is private to spectator sockets. Player transports do not
  /// receive these messages, and the host app never surfaces them.
  /// Returns false when nothing was sent, so the input keeps its text.
  bool sendSpectatorChat(String text) {
    final message = text.trim();
    if (!state.isSpectator || !isValidFourSpectatorChat(message)) return false;
    netSendSpectatorChat(text: message);
    state = state.copyWith(
      spectatorChat: _capped([
        ...state.spectatorChat,
        FourSpectatorChatMessage(message, true, senderName: state.myName),
      ]),
    );
    return true;
  }

  static List<FourSpectatorChatMessage> _capped(
    List<FourSpectatorChatMessage> l,
  ) => l.length > maxChatLines ? l.sublist(l.length - maxChatLines) : l;

  void leave() {
    _stopAdvertising();
    netLeave();
    _sub?.cancel();
    _sub = null;
    _match = null;
    _pendingMatchEvents.clear();
    _pendingTerminalEvent = null;
    state = FourLanState(
      session: reduceMultiBoard(state.session, const MbLeft()),
    );
  }
}

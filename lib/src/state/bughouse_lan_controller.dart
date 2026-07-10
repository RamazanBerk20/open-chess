import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/src/rust/api/net.dart';
import 'package:open_chess/src/state/bughouse_controller.dart';
import 'package:open_chess/src/state/lan_profile.dart';
import 'package:open_chess/src/state/player_profile.dart';

/// Lobby + live-session state for a networked Bughouse match.
class BughouseLanState {
  final bool active; // a host/join session is running
  final bool isHost;
  final bool started; // BugStart received → match underway
  final List<String>
  joiners; // host lobby: joined player names (connection order)
  final List<PlayerProfile> joinerProfiles;
  final List<int> mySeats; // seats this device controls (after start)
  final List<String> seatNames; // the four player names
  final List<PlayerProfile> seatProfiles;
  final String? error;

  const BughouseLanState({
    this.active = false,
    this.isHost = false,
    this.started = false,
    this.joiners = const [],
    this.joinerProfiles = const [],
    this.mySeats = const [],
    this.seatNames = const [],
    this.seatProfiles = const [],
    this.error,
  });

  BughouseLanState copyWith({
    bool? active,
    bool? isHost,
    bool? started,
    List<String>? joiners,
    List<PlayerProfile>? joinerProfiles,
    List<int>? mySeats,
    List<String>? seatNames,
    List<PlayerProfile>? seatProfiles,
    String? error,
  }) => BughouseLanState(
    active: active ?? this.active,
    isHost: isHost ?? this.isHost,
    started: started ?? this.started,
    joiners: joiners ?? this.joiners,
    joinerProfiles: joinerProfiles ?? this.joinerProfiles,
    mySeats: mySeats ?? this.mySeats,
    seatNames: seatNames ?? this.seatNames,
    seatProfiles: seatProfiles ?? this.seatProfiles,
    error: error,
  );
}

final bughouseLanProvider =
    NotifierProvider<BughouseLanController, BughouseLanState>(
      BughouseLanController.new,
    );

class BughouseLanController extends Notifier<BughouseLanState> {
  StreamSubscription<NetEvent>? _sub;
  BughouseController?
  _match; // the live match controller (registered by the screen)
  final List<NetEvent> _pendingMatchEvents = <NetEvent>[];
  static const int _maxPendingMatchEvents = 128;

  @override
  BughouseLanState build() {
    ref.onDispose(() {
      _sub?.cancel();
      netLeave();
    });
    return const BughouseLanState();
  }

  void host(PlayerProfile profile) {
    _listen(
      netHostBughouse(
        profile: lanProfileWire(profile),
        baseMinutes: 0,
        incrementSeconds: 0,
      ),
      isHost: true,
    );
  }

  void join(String addr, PlayerProfile profile) {
    _listen(
      netJoinBughouse(addr: addr, profile: lanProfileWire(profile)),
      isHost: false,
    );
  }

  void _listen(Stream<NetEvent> stream, {required bool isHost}) {
    _sub?.cancel();
    state = BughouseLanState(active: true, isHost: isHost);
    _sub = stream.listen(
      _onEvent,
      onError: (e) => state = state.copyWith(error: '$e'),
    );
  }

  /// Host commits the seat assignment (`seatOwner[seat]` = connection index, or
  /// -1 for the host) and starts the match.
  void startAssign(List<int> seatOwner) {
    netBugStart(seatOwner: seatOwner);
  }

  /// The match screen registers its controller so broadcasts can be applied.
  void register(BughouseController match) {
    _match = match;
    for (final event in _pendingMatchEvents) {
      _applyToMatch(event);
    }
    _pendingMatchEvents.clear();
  }

  /// Detach a route-owned controller without closing the session. This is used
  /// before the controller is disposed, so late stream events are never sent to
  /// a disposed ChangeNotifier.
  void unregister(BughouseController match) {
    if (identical(_match, match)) _match = null;
  }

  void _onEvent(NetEvent e) {
    switch (e.kind) {
      case NetEventKind.bugJoin:
        final profile = lanProfileFromWire(e.peerProfile);
        state = state.copyWith(
          joiners: [...state.joiners, profile.username],
          joinerProfiles: [...state.joinerProfiles, profile],
        );
      case NetEventKind.bugStart:
        state = state.copyWith(
          started: true,
          mySeats: e.yourSeats.map((x) => x.toInt()).toList(),
          seatNames: e.seats,
          seatProfiles: e.seatProfiles.map(lanProfileFromWire).toList(),
        );
      case NetEventKind.bugMove:
        _applyOrQueue(e);
      case NetEventKind.bugPass:
        _applyOrQueue(e);
      case NetEventKind.bugResult:
        _applyOrQueue(e);
      case NetEventKind.disconnected:
        state = state.copyWith(error: e.text.isEmpty ? 'Disconnected' : e.text);
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
      state = state.copyWith(error: 'Too many pending match updates.');
      return;
    }
    _pendingMatchEvents.add(event);
  }

  void _applyToMatch(NetEvent event) {
    final match = _match;
    if (match == null) return;
    switch (event.kind) {
      case NetEventKind.bugMove:
        match.applyRemoteMove(event.board.toInt(), event.uci);
      case NetEventKind.bugPass:
        match.applyPass(
          event.toBoard.toInt(),
          event.toColor.toInt(),
          event.piece.toInt(),
        );
      case NetEventKind.bugResult:
        match.applyResult(event.winningTeam.toInt(), event.board.toInt());
      default:
        break;
    }
  }

  void leave() {
    netLeave();
    _sub?.cancel();
    _sub = null;
    _match = null;
    _pendingMatchEvents.clear();
    state = const BughouseLanState();
  }
}

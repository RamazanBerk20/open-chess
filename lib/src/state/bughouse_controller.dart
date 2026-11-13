import 'package:flutter/foundation.dart';

import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/state/l10n_labels.dart';
import 'package:open_chess/src/state/time_control.dart';

/// The two boards of a Bughouse match.
enum BugBoard { a, b }

PieceColor _opp(PieceColor c) =>
    c == PieceColor.white ? PieceColor.black : PieceColor.white;

/// The four seats. Teams: 1 = A-White + B-Black, 2 = A-Black + B-White
/// (partners play opposite colors on opposite boards).
enum BugSeat { aWhite, aBlack, bWhite, bBlack }

BugSeat seatOf(BugBoard board, PieceColor color) => switch ((board, color)) {
  (BugBoard.a, PieceColor.white) => BugSeat.aWhite,
  (BugBoard.a, PieceColor.black) => BugSeat.aBlack,
  (BugBoard.b, PieceColor.white) => BugSeat.bWhite,
  (BugBoard.b, PieceColor.black) => BugSeat.bBlack,
};

class BugConfig {
  final TimeControlOption tc;

  /// Seats controlled by this device, assigned by the LAN host authority.
  final Set<BugSeat> humanSeats;

  /// LAN: send a board-tagged move to the host authority (board 0=A, 1=B).
  final void Function(int board, String uci, int whiteMs, int blackMs) lanSend;

  const BugConfig({
    required this.tc,
    required this.humanSeats,
    required this.lanSend,
  });
}

class BugResult {
  final int winningTeam; // 1 or 2 (0 when [interrupted])
  final GameOutcome? reason; // null when reported over the network
  final BugBoard board; // the board that ended
  /// A [LanResultCode] when the match stopped without a winner (link lost,
  /// boards diverged).
  final String? interrupted;
  const BugResult(
    this.winningTeam,
    this.reason,
    this.board, {
    this.interrupted,
  });
}

class _Board {
  final ChessGame game;
  int? selected;
  Set<int> targets = {};
  int? handPiece; // reserve piece armed for a drop
  (int, int)? pendingPromo; // (from, to) awaiting a promotion choice
  // Premove chain queued while the remote opponent is to move here.
  List<(int, int)> premoves = [];
  int? premoveFrom;
  Set<int> premoveTargets = {};
  final bool flipped;
  _Board(this.game, this.flipped);

  /// Board after the queued premoves (raw relocations) for chained selection.
  List<SquarePiece?> previewBoard() {
    final board = game.view().board;
    if (premoves.isEmpty) return board;
    final out = List<SquarePiece?>.of(board);
    for (final (f, t) in premoves) {
      out[t] = out[f];
      out[f] = null;
    }
    return out;
  }

  Set<int> premoveTargetsAfter(int sq) => game
      .premoveTargetsAfter(
        premoves: [
          for (final (f, t) in premoves) ...[f, t],
        ],
        from: sq,
      )
      .toSet();

  void clearPremoves() {
    premoves = [];
    premoveFrom = null;
    premoveTargets = {};
  }
}

/// Drives a host-authoritative, two-board LAN Bughouse match. It holds two
/// [ChessGame] mirrors because the global game providers represent one board.
class BughouseController extends ChangeNotifier {
  final BugConfig config;
  late final _Board _a;
  late final _Board _b;

  BugResult? result;

  BughouseController(this.config) {
    final tc = config.tc;
    // Board A oriented White-bottom; Board B Black-bottom so the two boards
    // mirror (partners sit on opposite sides).
    _a = _Board(_makeGame(tc), false);
    _b = _Board(_makeGame(tc), true);
  }

  ChessGame _makeGame(TimeControlOption tc) => ChessGame.newVariant(
    variant: GameVariant.bughouse,
    baseMinutes: tc.baseMinutes ?? 0,
    incrementSeconds: tc.incrementSeconds,
    chess960Index: 0,
  );

  _Board _b_(BugBoard b) => b == BugBoard.a ? _a : _b;

  GameView viewOf(BugBoard b) => _b_(b).game.view();
  ClockSnapshot clockOf(BugBoard b) => _b_(b).game.clockSnapshot();
  bool flippedOf(BugBoard b) => _b_(b).flipped;
  int? selectedOf(BugBoard b) => _b_(b).selected;
  Set<int> targetsOf(BugBoard b) => _b_(b).targets;
  int? handPieceOf(BugBoard b) => _b_(b).handPiece;
  (int, int)? pendingPromoOf(BugBoard b) => _b_(b).pendingPromo;

  bool _isHuman(BugSeat seat) => config.humanSeats.contains(seat);

  /// Whether the side to move on `board` is controlled by a human right now.
  bool humanToMove(BugBoard board) {
    if (result != null) return false;
    final v = _b_(board).game.view();
    if (v.status != GameOutcome.ongoing) return false;
    return _isHuman(seatOf(board, v.sideToMove));
  }

  void _clearSel(_Board b) {
    b.selected = null;
    b.targets = {};
    b.handPiece = null;
  }

  // --- Human input -----------------------------------------------------------

  void tapSquare(BugBoard board, int sq) {
    if (result != null) return;
    final b = _b_(board);
    if (b.pendingPromo != null) return;
    final view = b.game.view();
    final color = view.sideToMove;
    if (!_isHuman(seatOf(board, color))) {
      _premoveTap(board, sq); // opponent to move here → queue a premove
      return;
    }

    if (b.handPiece != null) {
      if (b.targets.contains(sq)) {
        _doDrop(board, sq);
      } else {
        _clearSel(b);
        notifyListeners();
      }
      return;
    }

    final piece = view.board[sq];
    final sel = b.selected;
    if (sel == null) {
      if (piece != null && piece.color == color) {
        b.selected = sq;
        b.targets = b.game.legalTargets(from: sq).toSet();
        notifyListeners();
      }
      return;
    }
    if (sq == sel) {
      _clearSel(b);
      notifyListeners();
      return;
    }
    if (b.targets.contains(sq)) {
      _doMove(board, sel, sq);
      return;
    }
    if (piece != null && piece.color == color) {
      b.selected = sq;
      b.targets = b.game.legalTargets(from: sq).toSet();
    } else {
      _clearSel(b);
    }
    notifyListeners();
  }

  void dragMove(BugBoard board, int from, int to) {
    if (result != null) return;
    final b = _b_(board);
    if (b.pendingPromo != null) return;
    final view = b.game.view();
    final color = view.sideToMove;
    if (!_isHuman(seatOf(board, color))) {
      _premoveDrag(board, from, to); // opponent to move here → queue a premove
      return;
    }
    final piece = view.board[from];
    if (piece == null || piece.color != color) return;
    final targets = b.game.legalTargets(from: from).toSet();
    if (!targets.contains(to)) {
      b.selected = from;
      b.targets = targets;
      notifyListeners();
      return;
    }
    _doMove(board, from, to);
  }

  void selectHand(BugBoard board, int piece) {
    if (result != null) return;
    final b = _b_(board);
    if (b.pendingPromo != null) return;
    final color = b.game.view().sideToMove;
    if (!_isHuman(seatOf(board, color))) return;
    final targets = b.game.dropTargets(piece: piece).toSet();
    if (targets.isEmpty) return;
    b.selected = null;
    b.handPiece = piece;
    b.targets = targets;
    notifyListeners();
  }

  void completePromotion(BugBoard board, PieceKind kind) {
    final b = _b_(board);
    final pp = b.pendingPromo;
    if (pp == null) return;
    const codes = {
      PieceKind.queen: 'q',
      PieceKind.rook: 'r',
      PieceKind.bishop: 'b',
      PieceKind.knight: 'n',
    };
    _lanSend(board, '${_su(pp.$1)}${_su(pp.$2)}${codes[kind] ?? 'q'}');
    b.pendingPromo = null;
    _clearSel(b);
    notifyListeners();
  }

  void cancelPromotion(BugBoard board) {
    _b_(board).pendingPromo = null;
    notifyListeners();
  }

  // --- Premove (queue a move while the opponent is to move on a board) --------

  List<(int, int)> premovesOf(BugBoard b) => _b_(b).premoves;
  int? premoveFromOf(BugBoard b) => _b_(b).premoveFrom;
  Set<int> premoveTargetsOf(BugBoard b) => _b_(b).premoveTargets;

  /// The colour we control on `board` that is NOT currently to move (the side a
  /// premove would be for), or null if we don't control the waiting seat.
  PieceColor? _premoveColor(BugBoard board) {
    final waiting = _opp(_b_(board).game.view().sideToMove);
    return _isHuman(seatOf(board, waiting)) ? waiting : null;
  }

  void _premoveTap(BugBoard board, int sq) {
    final my = _premoveColor(board);
    if (my == null) return;
    final b = _b_(board);
    final piece = b.previewBoard()[sq];
    final selFrom = b.premoveFrom;
    if (selFrom == null) {
      if (piece != null && piece.color == my) {
        b.premoveFrom = sq;
        b.premoveTargets = b.premoveTargetsAfter(sq);
      } else {
        b.clearPremoves();
      }
      notifyListeners();
      return;
    }
    if (sq == selFrom) {
      b.premoveFrom = null;
      b.premoveTargets = {};
      notifyListeners();
      return;
    }
    if (b.premoveTargets.contains(sq)) {
      b.premoves = [...b.premoves, (selFrom, sq)];
      b.premoveFrom = null;
      b.premoveTargets = {};
      notifyListeners();
      return;
    }
    if (piece != null && piece.color == my) {
      b.premoveFrom = sq;
      b.premoveTargets = b.premoveTargetsAfter(sq);
    } else {
      b.premoveFrom = null;
      b.premoveTargets = {};
    }
    notifyListeners();
  }

  void _premoveDrag(BugBoard board, int from, int to) {
    final my = _premoveColor(board);
    if (my == null) return;
    final b = _b_(board);
    final piece = b.previewBoard()[from];
    if (piece == null || piece.color != my) return;
    final targets = b.premoveTargetsAfter(from);
    if (targets.contains(to)) {
      b.premoves = [...b.premoves, (from, to)];
      b.premoveFrom = null;
      b.premoveTargets = {};
    } else {
      b.premoveFrom = from;
      b.premoveTargets = targets;
    }
    notifyListeners();
  }

  /// After a move lands on `board`, play the front of our premove chain there if
  /// it is now our turn. Keep the rest for the next reply; drop all if illegal.
  void _tryPremove(BugBoard board) {
    final b = _b_(board);
    if (result != null || b.premoves.isEmpty) return;
    final v = b.game.view();
    if (v.status != GameOutcome.ongoing) {
      b.clearPremoves();
      return;
    }
    if (!_isHuman(seatOf(board, v.sideToMove))) return; // still opponent's turn
    final pm = b.premoves.first;
    final rest = b.premoves.sublist(1);
    final isPromo =
        (v.board[pm.$1]?.kind == PieceKind.pawn) && (pm.$2 < 8 || pm.$2 >= 56);
    _lanSend(board, '${_su(pm.$1)}${_su(pm.$2)}${isPromo ? 'q' : ''}');
    b.premoves = rest;
    b.premoveFrom = null;
    b.premoveTargets = {};
    notifyListeners();
  }

  // --- Move application -------------------------------------------------------

  void _doMove(BugBoard board, int from, int to) {
    final b = _b_(board);
    // Don't mutate the local mirror — the host validates and echoes moves.
    final piece = b.game.view().board[from];
    final isPromo = piece?.kind == PieceKind.pawn && (to < 8 || to >= 56);
    if (isPromo) {
      b.selected = null;
      b.targets = {};
      b.handPiece = null;
      b.pendingPromo = (from, to);
    } else {
      _lanSend(board, '${_su(from)}${_su(to)}');
      _clearSel(b);
    }
    notifyListeners();
  }

  void _doDrop(BugBoard board, int to) {
    final b = _b_(board);
    final piece = b.handPiece;
    if (piece == null) return;
    _lanSend(board, '${const ['P', 'N', 'B', 'R', 'Q'][piece]}@${_su(to)}');
    _clearSel(b);
    notifyListeners();
  }

  // --- LAN (host broadcasts drive these mirrors) ------------------------------

  static String _su(int sq) =>
      '${String.fromCharCode(97 + sq % 8)}${sq ~/ 8 + 1}';

  void _lanSend(BugBoard board, String uci) {
    final snap = _b_(board).game.clockSnapshot();
    config.lanSend(
      board == BugBoard.a ? 0 : 1,
      uci,
      snap.whiteMs,
      snap.blackMs,
    );
  }

  /// Apply a move the host broadcast (its authority already validated it).
  void applyRemoteMove(int board, String uci) {
    if (result != null) return;
    final b = board == 0 ? _a : _b;
    bool ok;
    try {
      ok = b.game.playUci(uci: uci);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      // The host's move does not fit our mirror: stop loudly, not silently.
      _interrupt(LanResultCode.boardDesync, board);
      return;
    }
    {
      _clearSel(b);
      b.premoveFrom = null; // drop any stale in-progress premove selection
      b.premoveTargets = {};
      notifyListeners();
      _tryPremove(board == 0 ? BugBoard.a : BugBoard.b);
    }
  }

  /// Apply a partner feed the host broadcast.
  void applyPass(int board, int color, int piece) {
    final b = board == 0 ? _a : _b;
    b.game.giveToHand(
      color: color == 0 ? PieceColor.white : PieceColor.black,
      piece: const [
        PieceKind.pawn,
        PieceKind.knight,
        PieceKind.bishop,
        PieceKind.rook,
        PieceKind.queen,
      ][piece],
    );
    notifyListeners();
  }

  /// Apply the host's match result.
  void applyResult(int team, int board) {
    if (result != null) return;
    result = BugResult(team, null, board == 0 ? BugBoard.a : BugBoard.b);
    notifyListeners();
  }

  /// The host disappeared mid-match: end the mirror with a visible result.
  void markConnectionLost() =>
      _interrupt(LanResultCode.opponentDisconnected, 0);

  void _interrupt(String code, int board) {
    if (result != null) return;
    _clearSel(_a);
    _clearSel(_b);
    result = BugResult(
      0,
      null,
      board == 0 ? BugBoard.a : BugBoard.b,
      interrupted: code,
    );
    notifyListeners();
  }
}

//! Game wrapper: move history (for takeback), position-hash history (for
//! threefold repetition) and termination/draw detection.

use crate::error::Result;
use crate::fen::parse_fen;
use crate::position::{Position, Undo};
use crate::types::{file_of, rank_of, Color, Move, MoveList, Piece, Variant};

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum GameStatus {
    Ongoing,
    Checkmate {
        winner: Color,
    },
    /// A variant-specific win (three checks, king on the hill, king exploded).
    VariantWin {
        winner: Color,
    },
    Stalemate,
    DrawFiftyMove,
    DrawThreefold,
    DrawInsufficientMaterial,
}

#[derive(Clone)]
pub struct Game {
    pub pos: Position,
    history: Vec<(Move, Undo)>,
    /// Position hashes; index 0 is the start position, one entry per ply after.
    hashes: Vec<u64>,
}

impl Game {
    pub fn new() -> Game {
        Game::from_position(Position::startpos())
    }

    pub fn from_fen(fen: &str) -> Result<Game> {
        Ok(Game::from_position(parse_fen(fen)?))
    }

    pub fn from_position(pos: Position) -> Game {
        let h = pos.hash;
        Game {
            pos,
            history: Vec::new(),
            hashes: vec![h],
        }
    }

    pub fn legal_moves(&mut self) -> MoveList {
        self.pos.generate_legal()
    }

    /// Apply a legal move and record history.
    pub fn make_move(&mut self, mv: Move) {
        let u = self.pos.make_move(mv);
        self.history.push((mv, u));
        self.hashes.push(self.pos.hash);
    }

    /// Take back the last move, if any.
    pub fn undo(&mut self) -> bool {
        if let Some((mv, u)) = self.history.pop() {
            self.pos.unmake_move(mv, u);
            self.hashes.pop();
            true
        } else {
            false
        }
    }

    pub fn ply(&self) -> usize {
        self.history.len()
    }

    /// Position-hash history (one entry per ply, index 0 = start), for the AI's
    /// repetition detection.
    pub fn hash_history(&self) -> Vec<u64> {
        self.hashes.clone()
    }

    /// Discard move/repetition history after externally restoring a complete
    /// position snapshot. The current position becomes the only known start.
    pub fn reset_history(&mut self) {
        self.history.clear();
        self.hashes.clear();
        self.hashes.push(self.pos.hash);
    }

    /// How many times the current position has occurred (>=3 means threefold).
    pub fn repetition_count(&self) -> usize {
        let cur = self.pos.hash;
        self.hashes.iter().filter(|&&h| h == cur).count()
    }

    pub fn status(&mut self) -> GameStatus {
        // Variant win conditions (three-check / king-of-the-hill / atomic king
        // explosion) take precedence over the normal terminal checks.
        if let Some(winner) = self.pos.variant_terminal() {
            return GameStatus::VariantWin { winner };
        }
        let side = self.pos.side;
        let legal = self.pos.generate_legal();
        if legal.is_empty() {
            // Fog of War has no check concept — a stuck side is just a draw.
            if self.pos.variant == Variant::FogOfWar {
                return GameStatus::Stalemate;
            }
            return if self.pos.in_check(side) {
                GameStatus::Checkmate { winner: side.opp() }
            } else {
                GameStatus::Stalemate
            };
        }
        if self.is_insufficient_material() {
            return GameStatus::DrawInsufficientMaterial;
        }
        if self.pos.halfmove >= 100 {
            return GameStatus::DrawFiftyMove;
        }
        if self.repetition_count() >= 3 {
            return GameStatus::DrawThreefold;
        }
        GameStatus::Ongoing
    }

    /// Draw by insufficient material for the active variant: neither side
    /// can ever win. Variants where a bare king can still win or material can
    /// come back (King of the Hill, Crazyhouse, Bughouse, Fog of War) never
    /// draw this way.
    pub fn is_insufficient_material(&self) -> bool {
        let p = &self.pos;
        match p.variant {
            Variant::Standard | Variant::Chess960 => fide_dead_material(p),
            // Any piece can deliver checks, so only bare kings are a draw.
            Variant::ThreeCheck => {
                p.insufficient_to_mate(Color::White) && p.insufficient_to_mate(Color::Black)
            }
            // Kings cannot capture, so nothing can explode a bare king; a single
            // minor cannot mate a bare king either and has nothing to capture.
            Variant::Atomic => {
                let others = p.all
                    & !(p.pieces(Color::White, Piece::King) | p.pieces(Color::Black, Piece::King));
                let minors = p.pieces(Color::White, Piece::Knight)
                    | p.pieces(Color::Black, Piece::Knight)
                    | p.pieces(Color::White, Piece::Bishop)
                    | p.pieces(Color::Black, Piece::Bishop);
                others == 0 || (others.count_ones() == 1 && others & minors != 0)
            }
            Variant::KingOfTheHill
            | Variant::Crazyhouse
            | Variant::Bughouse
            | Variant::FogOfWar => false,
        }
    }

    /// The single terminal state of this game (move-derived results only;
    /// clock/resign/agreement results are layered on by the caller).
    pub fn termination(&mut self) -> Termination {
        self.status().into()
    }
}

/// FIDE dead-position material: KvK, KNvK, KBvK, or only same-coloured bishops.
fn fide_dead_material(p: &Position) -> bool {
    for c in [Color::White, Color::Black] {
        if p.pieces(c, Piece::Pawn) != 0
            || p.pieces(c, Piece::Rook) != 0
            || p.pieces(c, Piece::Queen) != 0
        {
            return false;
        }
    }
    let knights = (p.pieces(Color::White, Piece::Knight) | p.pieces(Color::Black, Piece::Knight))
        .count_ones();
    let bishops_bb = p.pieces(Color::White, Piece::Bishop) | p.pieces(Color::Black, Piece::Bishop);
    if knights == 0 && bishops_bb == 0 {
        return true; // KvK
    }
    if knights == 1 && bishops_bb == 0 {
        return true; // KNvK
    }
    if knights == 0 {
        return single_square_colour(bishops_bb);
    }
    false
}

fn single_square_colour(mut bb: crate::bitboard::Bitboard) -> bool {
    let mut colors = 0u8;
    while bb != 0 {
        let sq = crate::bitboard::pop_lsb(&mut bb);
        colors |= 1 << ((file_of(sq) + rank_of(sq)) & 1);
    }
    colors != 0b11
}

impl Position {
    /// Whether `side` can never win by any sequence under this variant (used
    /// for the "flag fall against insufficient material is a draw" rule).
    pub fn insufficient_to_mate(&self, side: Color) -> bool {
        let own = |p: Piece| self.pieces(side, p);
        let bare_king = self.occ[side.index()] == own(Piece::King);
        match self.variant {
            Variant::Standard | Variant::Chess960 => {
                if own(Piece::Pawn) | own(Piece::Rook) | own(Piece::Queen) != 0 {
                    return false;
                }
                let knights = own(Piece::Knight).count_ones();
                let bishops = own(Piece::Bishop);
                (knights + bishops.count_ones() <= 1)
                    || (knights == 0 && single_square_colour(bishops))
            }
            // A bare king can neither give check nor capture (Atomic).
            Variant::ThreeCheck | Variant::Atomic => bare_king,
            // The king can walk to the hill, captures refill the hand, and in
            // Fog of War a king can capture the enemy king.
            Variant::KingOfTheHill
            | Variant::Crazyhouse
            | Variant::Bughouse
            | Variant::FogOfWar => false,
        }
    }
}

/// Why a game was won.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum WinReason {
    Checkmate,
    /// Three checks, king on the hill, king exploded or captured.
    Variant,
    Time,
    Resign,
    Forfeit,
}

/// Why a game was drawn.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DrawReason {
    Stalemate,
    FiftyMove,
    Threefold,
    Insufficient,
    Agreement,
    /// A flag fell but the opponent could never have won.
    TimeVsInsufficient,
}

/// The one terminal state of a game. Every string or flattened enum on the
/// bridge is formatted from this, so contradictory combinations (a timeout
/// together with a checkmate, say) cannot be represented.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Termination {
    Ongoing,
    Decisive { winner: Color, reason: WinReason },
    Draw(DrawReason),
}

impl Termination {
    pub fn is_over(self) -> bool {
        self != Termination::Ongoing
    }

    /// Result of `flagged` running out of time in `pos`.
    pub fn on_time(pos: &Position, flagged: Color) -> Termination {
        if pos.insufficient_to_mate(flagged.opp()) {
            Termination::Draw(DrawReason::TimeVsInsufficient)
        } else {
            Termination::Decisive {
                winner: flagged.opp(),
                reason: WinReason::Time,
            }
        }
    }

    /// Stable LAN wire code for a move-derived result (`game_over:<code>`).
    pub fn code(self) -> &'static str {
        match self {
            Termination::Ongoing => "ongoing",
            Termination::Decisive {
                winner: Color::White,
                ..
            } => "white_wins",
            Termination::Decisive {
                winner: Color::Black,
                ..
            } => "black_wins",
            Termination::Draw(DrawReason::Stalemate) => "stalemate",
            Termination::Draw(DrawReason::FiftyMove) => "draw_fifty",
            Termination::Draw(DrawReason::Threefold) => "draw_threefold",
            Termination::Draw(DrawReason::Insufficient | DrawReason::TimeVsInsufficient) => {
                "draw_insufficient"
            }
            Termination::Draw(DrawReason::Agreement) => "draw_agreement",
        }
    }
}

impl From<GameStatus> for Termination {
    fn from(s: GameStatus) -> Termination {
        match s {
            GameStatus::Ongoing => Termination::Ongoing,
            GameStatus::Checkmate { winner } => Termination::Decisive {
                winner,
                reason: WinReason::Checkmate,
            },
            GameStatus::VariantWin { winner } => Termination::Decisive {
                winner,
                reason: WinReason::Variant,
            },
            GameStatus::Stalemate => Termination::Draw(DrawReason::Stalemate),
            GameStatus::DrawFiftyMove => Termination::Draw(DrawReason::FiftyMove),
            GameStatus::DrawThreefold => Termination::Draw(DrawReason::Threefold),
            GameStatus::DrawInsufficientMaterial => Termination::Draw(DrawReason::Insufficient),
        }
    }
}

impl Default for Game {
    fn default() -> Self {
        Game::new()
    }
}

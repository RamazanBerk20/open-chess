//! FEN parsing and generation.

use crate::attacks::pawn_attacks;
use crate::bitboard::{RANK_1, RANK_8};
use crate::error::{ChessError, Result};
use crate::position::Position;
use crate::types::{
    file_of, make_square, parse_square, rank_of, square_name, CastlingRights, Color, Piece, Variant,
};

/// Variant state that a plain FEN cannot carry (Three-check counters,
/// Crazyhouse/Bughouse reserves and the promoted-piece mask). Kept as one value
/// so every caller restores it through the same validated path.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct VariantExtras {
    /// Checks delivered, [white, black].
    pub checks: [u8; 2],
    /// Reserve counts, [colour][Pawn..Queen].
    pub hand: [[u8; 5]; 2],
    /// Squares holding a promoted piece (Crazyhouse/Bughouse).
    pub promoted: u64,
}

/// No reserve can legitimately hold more pieces than both Bughouse boards
/// contain; the cap also keeps `u8` counters far from overflow.
const MAX_HAND_COUNT: u8 = 64;
/// Absurd move counters are clamped instead of overflowing later.
const MAX_FULLMOVE: u32 = 100_000;

/// Parse a FEN as Standard chess, or as Chess960 when the castling field uses
/// Shredder letters. The position is validated under that variant.
pub fn parse_fen(fen: &str) -> Result<Position> {
    let shredder = fen
        .split_whitespace()
        .nth(2)
        .is_some_and(|c| c.chars().any(|ch| matches!(ch, 'A'..='H' | 'a'..='h')));
    let variant = if shredder {
        Variant::Chess960
    } else {
        Variant::Standard
    };
    parse_fen_variant(fen, variant, &VariantExtras::default())
}

/// Parse `fen` for `variant`, apply the state FEN does not carry, and validate
/// the result under that variant's rules. Anything the move generator cannot
/// handle is rejected with [`ChessError::InvalidFen`] (never a panic).
pub fn parse_fen_variant(fen: &str, variant: Variant, extras: &VariantExtras) -> Result<Position> {
    let err = |reason: &str| ChessError::InvalidFen(format!("{fen} ({reason})"));
    let parts: Vec<&str> = fen.split_whitespace().collect();
    if parts.len() < 4 {
        return Err(err("expected at least four fields"));
    }

    let mut pos = Position::empty();
    pos.variant = variant;

    // Piece placement (rank 8 first).
    let rows: Vec<&str> = parts[0].split('/').collect();
    if rows.len() != 8 {
        return Err(err("expected eight ranks"));
    }
    for (i, row) in rows.iter().enumerate() {
        let rank = 7 - i as u8;
        let mut file = 0u32;
        for ch in row.chars() {
            if let Some(d) = ch.to_digit(10) {
                if d == 0 || file + d > 8 {
                    return Err(err("rank does not describe eight files"));
                }
                file += d;
            } else {
                let color = if ch.is_ascii_uppercase() {
                    Color::White
                } else {
                    Color::Black
                };
                let piece = Piece::from_char(ch).ok_or_else(|| err("unknown piece letter"))?;
                if file > 7 {
                    return Err(err("rank does not describe eight files"));
                }
                pos.put_piece(color, piece, make_square(file as u8, rank));
                file += 1;
            }
        }
        if file != 8 {
            return Err(err("rank does not describe eight files"));
        }
    }
    for c in [Color::White, Color::Black] {
        if pos.pieces(c, Piece::King).count_ones() != 1 {
            return Err(err("each side needs exactly one king"));
        }
    }

    pos.side = match parts[1] {
        "w" => Color::White,
        "b" => Color::Black,
        _ => return Err(err("side to move must be w or b")),
    };

    parse_castling(&mut pos, parts[2]).map_err(err)?;

    pos.ep = if parts[3] == "-" {
        None
    } else {
        Some(parse_square(parts[3]).ok_or_else(|| err("bad en-passant square"))?)
    };

    pos.halfmove = parts
        .get(4)
        .and_then(|s| s.parse::<u32>().ok())
        .map_or(0, |v| v.min(u16::MAX as u32) as u16);
    pos.fullmove = parts
        .get(5)
        .and_then(|s| s.parse::<u32>().ok())
        .map_or(1, |v| v.clamp(1, MAX_FULLMOVE));

    pos.checks = extras.checks;
    pos.hand = extras.hand;
    pos.promoted = extras.promoted;

    pos.validate().map_err(err)?;

    // Keep the ep target only if the side to move can actually capture en
    // passant (keeps the hash/FEN strict and matches make_move).
    if let Some(ep_sq) = pos.ep {
        if pawn_attacks(pos.side.opp(), ep_sq) & pos.pieces(pos.side, Piece::Pawn) == 0 {
            pos.ep = None;
        }
    }
    pos.hash = pos.compute_hash();
    Ok(pos)
}

/// Interpret the castling field for `pos.variant`. Chess960 accepts Shredder
/// letters (rook file) and X-FEN `KQkq` (outermost rook on that side); other
/// variants accept `KQkq` (and the equivalent `HAha`) for the standard
/// e-file king and corner rooks only. Placement is checked by `validate`.
fn parse_castling(pos: &mut Position, field: &str) -> std::result::Result<(), &'static str> {
    use CastlingRights as CR;
    pos.castle_king_home = [pos.king_sq(Color::White), pos.king_sq(Color::Black)];
    if field == "-" {
        return Ok(());
    }
    let is960 = pos.variant == Variant::Chess960;
    for ch in field.chars() {
        let color = if ch.is_ascii_uppercase() {
            Color::White
        } else {
            Color::Black
        };
        let back = if color == Color::White { 0u8 } else { 56u8 };
        let king = pos.castle_king_home[color.index()];
        if king < back || king > back + 7 {
            return Err("castling right without the king on its back rank");
        }
        let king_file = file_of(king);
        let rook_file = match ch.to_ascii_lowercase() {
            'k' | 'q' if is960 => {
                // X-FEN: the outermost rook on that side of the king.
                let kingside = ch.eq_ignore_ascii_case(&'k');
                let files: Vec<u8> = if kingside {
                    (king_file + 1..8).rev().collect()
                } else {
                    (0..king_file).collect()
                };
                files
                    .into_iter()
                    .find(|&f| pos.piece_at(back + f) == Some((color, Piece::Rook)))
                    .ok_or("castling right without its rook")?
            }
            'k' => 7,
            'q' => 0,
            f @ 'a'..='h' => {
                let f = f as u8 - b'a';
                if !is960 && f != 0 && f != 7 {
                    return Err("castling file letters need Chess960");
                }
                f
            }
            _ => return Err("bad castling field"),
        };
        if rook_file == king_file {
            return Err("castling rook on the king's file");
        }
        let side = if rook_file > king_file { 0 } else { 1 };
        let flag = match (color, side) {
            (Color::White, 0) => CR::WK,
            (Color::White, _) => CR::WQ,
            (Color::Black, 0) => CR::BK,
            (Color::Black, _) => CR::BQ,
        };
        if pos.castling.has(flag) {
            return Err("duplicate castling right");
        }
        pos.castling.add(flag);
        pos.castle_rook_sq[color.index()][side] = back + rook_file;
    }
    Ok(())
}

impl Position {
    /// Check that this position is one the move generator can handle under
    /// `self.variant`'s rules: one king per side, no pawn on a back rank, a
    /// consistent en-passant square and castling rights, sane variant state,
    /// and the side not to move not in check where the variant has check.
    pub fn validate(&self) -> std::result::Result<(), &'static str> {
        use crate::attacks::king_attacks;
        use CastlingRights as CR;
        for c in [Color::White, Color::Black] {
            if self.pieces(c, Piece::King).count_ones() != 1 {
                return Err("each side needs exactly one king");
            }
        }
        let pawns = self.pieces(Color::White, Piece::Pawn) | self.pieces(Color::Black, Piece::Pawn);
        if pawns & (RANK_1 | RANK_8) != 0 {
            return Err("pawn on the first or last rank");
        }

        if let Some(ep) = self.ep {
            // White to move: target on rank 6, the black pawn on rank 5.
            let (target_rank, pawn_sq, behind) = match self.side {
                Color::White => (5, ep.wrapping_sub(8), ep.wrapping_add(8)),
                Color::Black => (2, ep.wrapping_add(8), ep.wrapping_sub(8)),
            };
            if rank_of(ep) != target_rank
                || self.piece_at(pawn_sq) != Some((self.side.opp(), Piece::Pawn))
                || self.piece_at(ep).is_some()
                || self.piece_at(behind).is_some()
            {
                return Err("impossible en-passant square");
            }
        }

        let is960 = self.variant == Variant::Chess960;
        for (color, flags) in [
            (Color::White, [CR::WK, CR::WQ]),
            (Color::Black, [CR::BK, CR::BQ]),
        ] {
            let back = if color == Color::White { 0u8 } else { 56u8 };
            let king = self.castle_king_home[color.index()];
            for (side, flag) in flags.into_iter().enumerate() {
                if !self.castling.has(flag) {
                    continue;
                }
                let rook = self.castle_rook_sq[color.index()][side];
                let geometry_ok = if is960 {
                    rank_of(king) == rank_of(back)
                        && rank_of(rook) == rank_of(back)
                        && (side == 0) == (file_of(rook) > file_of(king))
                } else {
                    king == back + 4 && rook == back + if side == 0 { 7 } else { 0 }
                };
                if !geometry_ok
                    || self.piece_at(king) != Some((color, Piece::King))
                    || self.piece_at(rook) != Some((color, Piece::Rook))
                {
                    return Err("castling rights do not match the king and rook placement");
                }
            }
        }

        if self.checks.iter().any(|&c| c > 3) {
            return Err("three-check counter exceeds 3");
        }
        if self.hand.iter().flatten().any(|&n| n > MAX_HAND_COUNT) {
            return Err("reserve count out of range");
        }
        let promotable = self.all
            & !pawns
            & !(self.pieces(Color::White, Piece::King) | self.pieces(Color::Black, Piece::King));
        if self.promoted & !promotable != 0 {
            return Err("promoted mask marks a square without a promoted piece");
        }

        // The side that just moved must not have left its king capturable.
        let them = self.side.opp();
        let their_king = self.king_sq(them);
        let illegal = match self.variant {
            // No check exists: leaving a king en prise is legal.
            Variant::FogOfWar => false,
            // Kings cannot capture; touching kings shield each other.
            Variant::Atomic => {
                king_attacks(their_king) & self.pieces(self.side, Piece::King) == 0
                    && self.is_attacked_no_king(their_king, self.side)
            }
            _ => self.is_attacked(their_king, self.side),
        };
        if illegal {
            return Err("the side not to move is in check");
        }
        Ok(())
    }

    /// Replace the state FEN does not carry, revalidate and rehash. Used when a
    /// caller restores Three-check/Crazyhouse state onto a parsed position.
    pub fn set_variant_extras(&mut self, extras: &VariantExtras) -> Result<()> {
        let mut next = self.clone();
        next.checks = extras.checks;
        next.hand = extras.hand;
        next.promoted = extras.promoted;
        next.validate()
            .map_err(|reason| ChessError::InvalidFen(format!("{} ({reason})", to_fen(self))))?;
        next.hash = next.compute_hash();
        *self = next;
        Ok(())
    }
}

pub fn to_fen(pos: &Position) -> String {
    let mut s = String::new();
    for rank in (0..8).rev() {
        let mut empty = 0;
        for file in 0..8 {
            let sq = make_square(file, rank);
            match pos.piece_at(sq) {
                Some((c, p)) => {
                    if empty > 0 {
                        s.push_str(&empty.to_string());
                        empty = 0;
                    }
                    let ch = p.to_char();
                    s.push(if c == Color::White {
                        ch.to_ascii_uppercase()
                    } else {
                        ch
                    });
                }
                None => empty += 1,
            }
        }
        if empty > 0 {
            s.push_str(&empty.to_string());
        }
        if rank > 0 {
            s.push('/');
        }
    }

    s.push(' ');
    s.push(if pos.side == Color::White { 'w' } else { 'b' });

    s.push(' ');
    if pos.castling.0 == 0 {
        s.push('-');
    } else if pos.variant == Variant::Chess960 {
        // Shredder-FEN: the castling rook's file letter (upper = white).
        if pos.castling.has(CastlingRights::WK) {
            s.push((b'A' + file_of(pos.castle_rook_sq[0][0])) as char);
        }
        if pos.castling.has(CastlingRights::WQ) {
            s.push((b'A' + file_of(pos.castle_rook_sq[0][1])) as char);
        }
        if pos.castling.has(CastlingRights::BK) {
            s.push((b'a' + file_of(pos.castle_rook_sq[1][0])) as char);
        }
        if pos.castling.has(CastlingRights::BQ) {
            s.push((b'a' + file_of(pos.castle_rook_sq[1][1])) as char);
        }
    } else {
        if pos.castling.has(CastlingRights::WK) {
            s.push('K');
        }
        if pos.castling.has(CastlingRights::WQ) {
            s.push('Q');
        }
        if pos.castling.has(CastlingRights::BK) {
            s.push('k');
        }
        if pos.castling.has(CastlingRights::BQ) {
            s.push('q');
        }
    }

    s.push(' ');
    match pos.ep {
        Some(sq) => s.push_str(&square_name(sq)),
        None => s.push('-'),
    }

    s.push_str(&format!(" {} {}", pos.halfmove, pos.fullmove));
    s
}

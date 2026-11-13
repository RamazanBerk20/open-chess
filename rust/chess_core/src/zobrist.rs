//! Zobrist hashing keys, generated once from a fixed seed so hashes are stable
//! across runs (needed for repetition detection and the AI transposition table).

use rand::rngs::StdRng;
use rand::{RngCore, SeedableRng};
use std::sync::OnceLock;

use crate::types::{Color, Piece, Square};

pub struct Zobrist {
    /// [color][piece][square]
    piece: [[[u64; 64]; 6]; 2],
    /// XORed in when it is Black's turn.
    side: u64,
    /// Indexed by the 4-bit castling-rights mask (0..16).
    castle: [u64; 16],
    /// Indexed by the file of the en-passant square.
    ep_file: [u64; 8],
    /// Crazyhouse/Bughouse squares occupied by promoted pawns. They must be
    /// distinct from native pieces because captures return them as pawns.
    promoted: [u64; 64],
    /// Crazyhouse/Bughouse reserve: one independent key per exact count,
    /// [colour][Pawn..Queen][count]. Count 0 is 0 so empty hands hash as before.
    hand: [[[u64; HAND_KEYS]; 5]; 2],
    /// Three-check delivered-check counters, [colour][count]; count 0 is 0.
    checks: [[u64; CHECK_KEYS]; 2],
}

/// Counts at or above the last index share its key (validated positions keep
/// every reserve count far below it; a shared key only costs a collision).
pub const HAND_KEYS: usize = 65;
pub const CHECK_KEYS: usize = 16;

impl Zobrist {
    fn new() -> Zobrist {
        let mut rng = StdRng::seed_from_u64(0x00C0_FFEE_C0DE_F00D);
        let mut piece = [[[0u64; 64]; 6]; 2];
        for color in piece.iter_mut() {
            for pc in color.iter_mut() {
                for sq in pc.iter_mut() {
                    *sq = rng.next_u64();
                }
            }
        }
        let side = rng.next_u64();
        let mut castle = [0u64; 16];
        for c in castle.iter_mut() {
            *c = rng.next_u64();
        }
        let mut ep_file = [0u64; 8];
        for e in ep_file.iter_mut() {
            *e = rng.next_u64();
        }
        let mut promoted = [0u64; 64];
        for key in promoted.iter_mut() {
            *key = rng.next_u64();
        }
        let mut hand = [[[0u64; HAND_KEYS]; 5]; 2];
        for color in hand.iter_mut() {
            for pc in color.iter_mut() {
                for key in pc.iter_mut().skip(1) {
                    *key = rng.next_u64();
                }
            }
        }
        let mut checks = [[0u64; CHECK_KEYS]; 2];
        for color in checks.iter_mut() {
            for key in color.iter_mut().skip(1) {
                *key = rng.next_u64();
            }
        }
        Zobrist {
            piece,
            side,
            castle,
            ep_file,
            promoted,
            hand,
            checks,
        }
    }

    #[inline]
    pub fn piece(&self, c: Color, p: Piece, sq: Square) -> u64 {
        self.piece[c.index()][p.index()][sq as usize]
    }
    #[inline]
    pub fn side(&self) -> u64 {
        self.side
    }
    #[inline]
    pub fn castle(&self, mask: u8) -> u64 {
        self.castle[mask as usize]
    }
    #[inline]
    pub fn ep_file(&self, file: u8) -> u64 {
        self.ep_file[file as usize]
    }
    #[inline]
    pub fn promoted(&self, sq: Square) -> u64 {
        self.promoted[sq as usize]
    }
    /// Key for colour `c` holding exactly `count` pieces of hand index `piece`.
    #[inline]
    pub fn hand(&self, c: usize, piece: usize, count: u8) -> u64 {
        self.hand[c][piece][(count as usize).min(HAND_KEYS - 1)]
    }
    /// Key for colour `c` having delivered exactly `count` checks.
    #[inline]
    pub fn checks(&self, c: usize, count: u8) -> u64 {
        self.checks[c][(count as usize).min(CHECK_KEYS - 1)]
    }
}

static ZOBRIST: OnceLock<Zobrist> = OnceLock::new();

#[inline]
pub fn zobrist() -> &'static Zobrist {
    ZOBRIST.get_or_init(Zobrist::new)
}

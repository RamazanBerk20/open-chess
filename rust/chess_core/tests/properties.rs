//! Property tests without extra tooling: seeded random playouts for every
//! variant and mutated-FEN fuzzing. Run in release.

use chess_core::{
    parse_fen_variant, to_fen, Color, Piece, Position, Variant, VariantExtras, START_FEN,
};
use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};

const VARIANTS: [Variant; 8] = [
    Variant::Standard,
    Variant::ThreeCheck,
    Variant::KingOfTheHill,
    Variant::Chess960,
    Variant::Atomic,
    Variant::Crazyhouse,
    Variant::Bughouse,
    Variant::FogOfWar,
];

/// Bitboards, mailbox and the incremental hash all describe the same board.
fn assert_consistent(pos: &Position, context: &str) {
    let mut all = 0u64;
    for c in [Color::White, Color::Black] {
        let mut occ = 0u64;
        for p in Piece::ALL {
            let bb = pos.pieces(c, p);
            assert_eq!(occ & bb, 0, "{context}: overlapping bitboards");
            occ |= bb;
        }
        assert_eq!(pos.occ[c.index()], occ, "{context}: colour occupancy");
        all |= occ;
    }
    assert_eq!(pos.all, all, "{context}: total occupancy");
    for sq in 0..64u8 {
        let expected = Piece::ALL.iter().find_map(|&p| {
            [Color::White, Color::Black]
                .into_iter()
                .find(|&c| pos.pieces(c, p) & (1 << sq) != 0)
                .map(|c| (c, p))
        });
        assert_eq!(pos.piece_at(sq), expected, "{context}: mailbox at {sq}");
    }
    assert_eq!(pos.hash, pos.compute_hash(), "{context}: hash");
}

fn snapshot(pos: &Position) -> (String, u64, [u8; 2], [[u8; 5]; 2], u64) {
    (to_fen(pos), pos.hash, pos.checks, pos.hand, pos.promoted)
}

fn extras(pos: &Position) -> VariantExtras {
    VariantExtras {
        checks: pos.checks,
        hand: pos.hand,
        promoted: pos.promoted,
    }
}

fn start(variant: Variant, rng: &mut StdRng) -> Position {
    if variant == Variant::Chess960 {
        Position::chess960(rng.random_range(0..960))
    } else {
        parse_fen_variant(START_FEN, variant, &VariantExtras::default()).unwrap()
    }
}

#[test]
fn random_playouts_keep_make_unmake_and_hash_symmetric() {
    let mut rng = StdRng::seed_from_u64(0x0C0FFEE);
    for variant in VARIANTS {
        for game in 0..40 {
            let mut pos = start(variant, &mut rng);
            for ply in 0..160 {
                let ctx = format!("{variant:?} game {game} ply {ply} `{}`", to_fen(&pos));
                assert_consistent(&pos, &ctx);
                if pos.variant_terminal().is_some() {
                    break;
                }
                // Every reachable live position survives a FEN round trip.
                let reparsed = parse_fen_variant(&to_fen(&pos), variant, &extras(&pos))
                    .unwrap_or_else(|e| panic!("{ctx}: round trip rejected: {e}"));
                assert_eq!(reparsed.hash, pos.hash, "{ctx}: round-trip hash");

                let moves = pos.generate_legal();
                if moves.is_empty() {
                    break;
                }
                // Make/unmake every move and check exact restoration.
                let before = snapshot(&pos);
                for &mv in moves.as_slice() {
                    let undo = pos.make_move(mv);
                    assert_consistent(&pos, &format!("{ctx} after {mv:?}"));
                    pos.unmake_move(mv, undo);
                    assert_eq!(snapshot(&pos), before, "{ctx}: unmake {mv:?}");
                }
                let mv = moves[rng.random_range(0..moves.len())];
                pos.make_move(mv);
                // Bughouse: the partner board keeps feeding pieces.
                if variant == Variant::Bughouse && rng.random_bool(0.3) {
                    let c = if rng.random_bool(0.5) {
                        Color::White
                    } else {
                        Color::Black
                    };
                    pos.add_to_hand(c, Piece::ALL[rng.random_range(0..5)]);
                }
            }
        }
    }
}

const SEEDS: [&str; 6] = [
    START_FEN,
    "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
    "bqnb1rkr/pp3ppp/3ppn2/2p5/5P2/P2P4/NPP1P1PP/BQ1BNRKR w HFhf - 2 9",
    "4k3/8/8/3Pp3/8/8/8/4K3 w - e6 0 1",
    "8/8/8/3kK3/8/8/8/8 w - - 0 1",
    "r3k2r/8/8/8/8/8/6P1/R3K2R b KQkq - 0 1",
];
const ALPHABET: &[u8] = b"pnbrqkPNBRQK0123456789/ wb-KQkqABCDEFGHabcdefgh";

#[test]
fn mutated_fens_never_panic_or_corrupt() {
    let mut rng = StdRng::seed_from_u64(42);
    for round in 0..20_000 {
        let mut fen = SEEDS[round % SEEDS.len()].as_bytes().to_vec();
        for _ in 0..rng.random_range(1..4) {
            let at = rng.random_range(0..fen.len());
            let ch = ALPHABET[rng.random_range(0..ALPHABET.len())];
            match rng.random_range(0..3) {
                0 => fen[at] = ch,
                1 => fen.insert(at, ch),
                _ => {
                    fen.remove(at);
                    if fen.is_empty() {
                        fen.push(ch);
                    }
                }
            }
        }
        let fen = String::from_utf8(fen).unwrap();
        let variant = VARIANTS[round % VARIANTS.len()];
        let mut extras = VariantExtras::default();
        if matches!(variant, Variant::Crazyhouse | Variant::Bughouse) {
            extras.hand = [[1; 5], [1; 5]];
        }
        let Ok(mut pos) = parse_fen_variant(&fen, variant, &extras) else {
            continue;
        };
        let ctx = format!("{variant:?} `{fen}`");
        assert_consistent(&pos, &ctx);
        let moves = pos.generate_legal();
        let before = snapshot(&pos);
        for &mv in moves.as_slice() {
            let undo = pos.make_move(mv);
            assert_consistent(&pos, &format!("{ctx} after {mv:?}"));
            pos.unmake_move(mv, undo);
            assert_eq!(snapshot(&pos), before, "{ctx}: unmake {mv:?}");
        }
    }
}

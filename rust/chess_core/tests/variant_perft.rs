//! Perft for all eight variants. Reference counts are independent of this
//! engine: Chess960, Atomic, Crazyhouse and Three-check values are published
//! (python-chess `examples/perft/*.perft`, chessprogramming Chess960 list);
//! the others are derived below from standard perft by an argument that the
//! variant rule cannot act within the searched depth. Run in release.

use chess_core::{parse_fen, parse_fen_variant, Position, Variant, VariantExtras, START_FEN};

const KIWIPETE: &str = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1";

/// Perft that, like the reference implementations, has no moves once a
/// variant win (three checks, hill, exploded king) has happened.
fn perft(pos: &mut Position, depth: u32) -> u64 {
    if depth == 0 {
        return 1;
    }
    if pos.variant_terminal().is_some() {
        return 0;
    }
    let moves = pos.generate_legal();
    if depth == 1 {
        return moves.len() as u64;
    }
    let mut n = 0;
    for &mv in moves.as_slice() {
        let undo = pos.make_move(mv);
        n += perft(pos, depth - 1);
        pos.unmake_move(mv, undo);
    }
    n
}

fn run(fen: &str, variant: Variant, extras: VariantExtras, expected: &[u64]) {
    let mut pos = parse_fen_variant(fen, variant, &extras).unwrap();
    for (i, &n) in expected.iter().enumerate() {
        let depth = i as u32 + 1;
        assert_eq!(
            perft(&mut pos, depth),
            n,
            "{variant:?} `{fen}` depth {depth}"
        );
    }
}

fn plain(fen: &str, variant: Variant, expected: &[u64]) {
    run(fen, variant, VariantExtras::default(), expected);
}

fn hands(white: [u8; 5], black: [u8; 5]) -> VariantExtras {
    VariantExtras {
        hand: [white, black],
        ..VariantExtras::default()
    }
}

#[test]
fn perft_chess960() {
    // chessprogramming.org "Chess960 Perft Results" positions 0 and 1.
    let mut a =
        parse_fen("bqnb1rkr/pp3ppp/3ppn2/2p5/5P2/P2P4/NPP1P1PP/BQ1BNRKR w HFhf - 2 9").unwrap();
    assert_eq!(a.variant, Variant::Chess960);
    for (d, n) in [(1, 21), (2, 528), (3, 12189), (4, 326672)] {
        assert_eq!(perft(&mut a, d), n, "960 #0 depth {d}");
    }
    plain(
        "2nnrbkr/p1qppppp/8/1ppb4/6PP/3PP3/PPP2P2/BQNNRBKR w HEhe - 1 9",
        Variant::Chess960,
        &[21, 807, 18002, 667366],
    );
}

#[test]
fn perft_atomic() {
    plain(START_FEN, Variant::Atomic, &[20, 400, 8902, 197326]);
    plain(
        "rn2kb1r/1pp1p2p/p2q1pp1/3P4/2P3b1/4PN2/PP3PPP/R2QKB1R b KQkq - 0 1",
        Variant::Atomic,
        &[40, 1238, 45237, 1434825],
    );
    plain(
        "rn1qkb1r/p5pp/2p5/3p4/N3P3/5P2/PPP4P/R1BQK3 w Qkq - 0 1",
        Variant::Atomic,
        &[28, 833, 23353, 714499],
    );
}

#[test]
fn perft_crazyhouse() {
    run(
        "2k5/8/8/8/8/8/8/4K3 w - - 0 1",
        Variant::Crazyhouse,
        hands([1; 5], [1; 5]),
        &[301, 75353],
    );
    run(
        "2k5/8/8/8/8/8/8/4K3 w - - 0 1",
        Variant::Crazyhouse,
        hands([0, 0, 0, 0, 1], [0, 1, 0, 0, 0]),
        &[67, 3083, 88634, 932554],
    );
    plain(
        "r1bqk2r/pppp1ppp/2n1p3/4P3/1b1Pn3/2NB1N2/PPP2PPP/R1BQK2R b KQkq - 0 1",
        Variant::Crazyhouse,
        &[42, 1347, 58057, 2083382],
    );
    run(
        "2rn1b1r/1pp2n1p/B1PBk1pP/5p1P/P5p1/2P2RP1/RP1QNP2/1NBK4 w - - 0 1",
        Variant::Crazyhouse,
        hands([1, 0, 0, 0, 1], [1, 0, 0, 0, 0]),
        &[99, 3932, 314782],
    );
}

#[test]
fn perft_bughouse() {
    // With empty hands nothing is ever dropped (captures feed the partner's
    // board, not this one), so Bughouse is standard chess move-for-move.
    plain(START_FEN, Variant::Bughouse, &[20, 400, 8902, 197281]);
    // A capture only changes the capturer's own hand, which first matters
    // two plies later; so up to the depths below Bughouse equals Crazyhouse.
    run(
        "2k5/8/8/8/8/8/8/4K3 w - - 0 1",
        Variant::Bughouse,
        hands([1; 5], [1; 5]),
        &[301, 75353],
    );
    run(
        "2k5/8/8/8/8/8/8/4K3 w - - 0 1",
        Variant::Bughouse,
        hands([0, 0, 0, 0, 1], [0, 1, 0, 0, 0]),
        &[67, 3083, 88634],
    );
}

#[test]
fn perft_three_check() {
    // python-chess 3check.perft (`1+1`: each side has delivered two checks).
    let two_each = VariantExtras {
        checks: [2, 2],
        ..VariantExtras::default()
    };
    run(KIWIPETE, Variant::ThreeCheck, two_each, &[48, 2039, 97848]);
    run(
        "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1",
        Variant::ThreeCheck,
        two_each,
        &[26, 562, 13410],
    );
}

#[test]
fn perft_king_of_the_hill() {
    // No king can reach d4/e4/d5/e5 within these depths (each king needs at
    // least three moves), so the hill rule cannot act: standard values.
    plain(START_FEN, Variant::KingOfTheHill, &[20, 400, 8902, 197281]);
    plain(KIWIPETE, Variant::KingOfTheHill, &[48, 2039, 97862]);
}

#[test]
fn perft_fog_of_war() {
    // Moves are pseudo-legal. From the start nobody can be in check or pinned
    // before ply 3, so the first three plies equal standard chess.
    plain(START_FEN, Variant::FogOfWar, &[20, 400, 8902]);
    // Hand-counted: Ke1 may step to d1, d2, f1, f2 and take on e2 (standard
    // chess allows only d1, f1 and Kxe2).
    plain("4k3/8/8/8/8/8/4r3/4K3 w - - 0 1", Variant::FogOfWar, &[5]);
    plain("4k3/8/8/8/8/8/8/R3K3 w - - 0 1", Variant::FogOfWar, &[15]);
}

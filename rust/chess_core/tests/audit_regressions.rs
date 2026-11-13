//! Regression tests for the 1.1.0 Rust audit findings (rules engine side).

use chess_core::{
    parse_fen, parse_fen_variant, to_fen, Color, Game, GameStatus, Piece, Variant, VariantExtras,
};

fn hand(white: [u8; 5], black: [u8; 5]) -> VariantExtras {
    VariantExtras {
        hand: [white, black],
        ..VariantExtras::default()
    }
}

#[test]
fn full_hand_on_empty_board_does_not_overflow_the_move_list() {
    // Kings only, White to move with one of each droppable piece: 302 moves.
    for variant in [Variant::Crazyhouse, Variant::Bughouse] {
        let mut pos = parse_fen_variant(
            "4k3/8/8/8/8/8/8/4K3 w - - 0 1",
            variant,
            &hand([1; 5], [0; 5]),
        )
        .unwrap();
        let moves = pos.generate_legal();
        assert!(moves.len() > 256, "{variant:?}: {}", moves.len());
        // Indexing and slicing agree past the inline capacity.
        assert_eq!(moves[moves.len() - 1], *moves.as_slice().last().unwrap());
    }
}

#[test]
fn bogus_en_passant_square_is_rejected() {
    assert!(parse_fen("4k3/8/8/8/4p3/3P4/8/4K3 w - e4 0 1").is_err());
    // Right rank but no pawn that just double-pushed.
    assert!(parse_fen("4k3/8/8/8/8/8/8/4K3 w - e6 0 1").is_err());
    // Genuine target stays.
    let p = parse_fen("4k3/8/8/3Pp3/8/8/8/4K3 w - e6 0 1").unwrap();
    assert_eq!(p.ep, Some(44));
}

#[test]
fn pawns_on_back_ranks_are_rejected() {
    assert!(parse_fen("P3k3/8/8/8/8/8/8/4K3 w - - 0 1").is_err());
    assert!(parse_fen("4k3/8/8/8/8/8/8/p3K3 w - - 0 1").is_err());
}

#[test]
fn castling_letters_must_match_the_variant_and_pieces() {
    // Shredder letter with the king off its back rank.
    assert!(parse_fen("4k3/8/8/8/4K3/8/8/7R w H - 0 1").is_err());
    for v in [Variant::Standard, Variant::Chess960, Variant::Atomic] {
        assert!(parse_fen_variant(
            "4k3/8/8/8/4K3/8/8/7R w H - 0 1",
            v,
            &VariantExtras::default()
        )
        .is_err());
    }
    // A non-corner file letter under Standard rules.
    assert!(parse_fen_variant(
        "4k3/8/8/8/8/8/8/1R2K3 w B - 0 1",
        Variant::Standard,
        &VariantExtras::default()
    )
    .is_err());
    // ...is a real Chess960 right.
    let p = parse_fen_variant(
        "4k3/8/8/8/8/8/8/1R2K3 w B - 0 1",
        Variant::Chess960,
        &VariantExtras::default(),
    )
    .unwrap();
    assert_eq!(p.castle_rook_sq[0][1], 1);
    // X-FEN KQ under Chess960 picks the outermost rooks.
    let p = parse_fen_variant(
        "4k3/8/8/8/8/8/8/1RK3R1 w KQ - 0 1",
        Variant::Chess960,
        &VariantExtras::default(),
    )
    .unwrap();
    assert_eq!(p.castle_rook_sq[0], [6, 1]);
}

#[test]
fn digit_overflow_is_rejected() {
    assert!(parse_fen("99999999999999999999999999999/8/8/8/8/8/8/4K2k w - - 0 1").is_err());
    assert!(parse_fen("4k3/8/8/8/8/8/8/4K30 w - - 0 1").is_err());
}

#[test]
fn atomic_touching_kings_are_legal_but_not_in_standard() {
    let fen = "8/8/8/3kK3/8/8/8/8 w - - 0 1";
    assert!(parse_fen(fen).is_err());
    let mut pos = parse_fen_variant(fen, Variant::Atomic, &VariantExtras::default()).unwrap();
    assert!(!pos.generate_legal().is_empty());
    // Atomic still rejects a real check on the side not to move.
    assert!(parse_fen_variant(
        "4k3/8/8/8/8/8/4R3/4K3 w - - 0 1",
        Variant::Atomic,
        &VariantExtras::default()
    )
    .is_err());
}

#[test]
fn fog_of_war_allows_a_king_left_en_prise() {
    let fen = "4k3/8/8/8/8/8/4r3/4K3 b - - 0 1";
    assert!(parse_fen(fen).is_err());
    assert!(parse_fen_variant(fen, Variant::FogOfWar, &VariantExtras::default()).is_ok());
}

#[test]
fn atomic_exploded_rook_loses_its_castling_right() {
    // Black bishop d5 takes g2: the blast removes the h1 rook.
    let mut pos = parse_fen_variant(
        "4k3/8/8/3b4/8/8/6P1/4K2R b K - 0 1",
        Variant::Atomic,
        &VariantExtras::default(),
    )
    .unwrap();
    let mv = pos.parse_uci("d5g2").unwrap();
    pos.make_move(mv);
    assert_eq!(pos.piece_at(7), None);
    assert_eq!(pos.castling.0, 0);
    assert!(pos.parse_uci("e1g1").is_err());
    assert_eq!(pos.hash, pos.compute_hash());
}

#[test]
fn fog_visibility_after_king_capture_does_not_panic() {
    let mut pos = parse_fen_variant(
        "4k3/8/8/8/8/8/4r3/4K3 b - - 0 1",
        Variant::FogOfWar,
        &VariantExtras::default(),
    )
    .unwrap();
    let mv = pos.parse_uci("e2e1").unwrap();
    pos.make_move(mv);
    assert_eq!(pos.pieces(Color::White, Piece::King), 0);
    let vis = pos.visible_mask(Color::White);
    assert_eq!(vis, 0);
    assert_ne!(pos.visible_mask(Color::Black), 0);
}

fn status(fen: &str, variant: Variant) -> GameStatus {
    let pos = parse_fen_variant(fen, variant, &VariantExtras::default()).unwrap();
    Game::from_position(pos).status()
}

#[test]
fn insufficient_material_is_variant_aware() {
    let kk = "4k3/8/8/8/8/8/8/4K3 w - - 0 1";
    let knk = "4k3/8/8/8/8/8/8/4KN2 w - - 0 1";
    assert_eq!(
        status(kk, Variant::Standard),
        GameStatus::DrawInsufficientMaterial
    );
    assert_eq!(status(kk, Variant::KingOfTheHill), GameStatus::Ongoing);
    assert_eq!(status(kk, Variant::FogOfWar), GameStatus::Ongoing);
    assert_eq!(
        status(kk, Variant::ThreeCheck),
        GameStatus::DrawInsufficientMaterial
    );
    assert_eq!(status(knk, Variant::ThreeCheck), GameStatus::Ongoing);
    assert_eq!(
        status(knk, Variant::Atomic),
        GameStatus::DrawInsufficientMaterial
    );
    assert_eq!(
        status("4k3/8/8/8/8/8/8/3QK3 w - - 0 1", Variant::Atomic),
        GameStatus::Ongoing
    );

    // Flag-fall rule: a bare king never wins, except where it can.
    let pos = parse_fen_variant(knk, Variant::Crazyhouse, &VariantExtras::default()).unwrap();
    assert!(!pos.insufficient_to_mate(Color::Black));
    let pos = parse_fen_variant(knk, Variant::ThreeCheck, &VariantExtras::default()).unwrap();
    assert!(!pos.insufficient_to_mate(Color::White));
    assert!(pos.insufficient_to_mate(Color::Black));
}

#[test]
fn san_is_not_disambiguated_by_a_drop() {
    let mut pos = parse_fen_variant(
        "4k3/8/8/8/8/8/8/1N2K1N1 w - - 0 1",
        Variant::Crazyhouse,
        &hand([0, 1, 0, 0, 0], [0; 5]),
    )
    .unwrap();
    // A drop's `from` field is the piece index (1 = knight = square b1), so the
    // drop N@f3 used to be read as "another knight from b1".
    let mv = pos.parse_uci("g1f3").unwrap();
    assert_eq!(pos.san_of(mv), "Nf3");
}

#[test]
fn distinct_hands_hash_differently() {
    let board = "4k3/8/8/8/8/8/8/4K3 w - - 0 1";
    let h = |e: VariantExtras| {
        parse_fen_variant(board, Variant::Crazyhouse, &e)
            .unwrap()
            .hash
    };
    // White queen vs black bishop collided under the old keys.
    assert_ne!(
        h(hand([0, 0, 0, 0, 1], [0; 5])),
        h(hand([0; 5], [0, 0, 1, 0, 0]))
    );
    assert_ne!(
        h(hand([2, 0, 0, 0, 0], [0; 5])),
        h(hand([1, 0, 0, 0, 0], [0; 5]))
    );
    assert_ne!(h(hand([0; 5], [0; 5])), h(hand([0; 5], [0, 0, 0, 0, 1])));
}

#[test]
fn variant_extras_are_validated() {
    let start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    let bad_checks = VariantExtras {
        checks: [4, 0],
        ..VariantExtras::default()
    };
    assert!(parse_fen_variant(start, Variant::ThreeCheck, &bad_checks).is_err());
    let bad_promoted = VariantExtras {
        promoted: 1 << 20,
        ..VariantExtras::default()
    };
    assert!(parse_fen_variant(start, Variant::Crazyhouse, &bad_promoted).is_err());
    assert!(
        parse_fen_variant(start, Variant::Crazyhouse, &hand([65, 0, 0, 0, 0], [0; 5])).is_err()
    );
    // Extreme move counters are clamped, not overflowed later.
    let mut p = parse_fen("4k3/8/8/8/8/8/8/R3K3 w - - 65535 4294967295").unwrap();
    let mv = p.parse_uci("a1a2").unwrap();
    p.make_move(mv);
    assert_eq!(p.halfmove, u16::MAX);
    assert!(to_fen(&p).ends_with("100000"));
}

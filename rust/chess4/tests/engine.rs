use chess4::board::{in_bounds, is_promo_square, Board, N, VALID};
use chess4::{Coord, Format, FourGame, FourResult, Move4, Piece, Player, PlayerStatus, Team};

fn at(g: &FourGame, c: i8, r: i8) -> Option<(Player, Piece)> {
    g.board.get(c, r)
}

#[test]
fn valid_mask_is_a_cross() {
    let valid = VALID.iter().filter(|&&v| v).count();
    assert_eq!(valid, 160);
    assert_eq!(N - valid, 36);
    assert!(!in_bounds(0, 0)); // cut corner
    assert!(!in_bounds(13, 13));
    assert!(in_bounds(7, 0)); // Red back rank
    assert!(in_bounds(0, 7)); // Blue back rank
}

#[test]
fn start_position_is_correct() {
    let b = Board::start();
    assert_eq!(b.cells.iter().filter(|c| c.is_some()).count(), 64);
    assert_eq!(b.get(7, 0), Some((Player::Red, Piece::King)));
    assert_eq!(b.get(6, 0), Some((Player::Red, Piece::Queen)));
    assert_eq!(b.get(0, 7), Some((Player::Blue, Piece::King)));
    assert_eq!(b.get(13, 6), Some((Player::Green, Piece::King))); // 180° swap
    assert_eq!(b.get(3, 1), Some((Player::Red, Piece::Pawn)));
    assert_eq!(b.get(1, 3), Some((Player::Blue, Piece::Pawn)));
}

#[test]
fn promo_zone_per_army() {
    assert!(is_promo_square(Player::Red, Coord::new(5, 10)));
    assert!(is_promo_square(Player::Yellow, Coord::new(5, 3)));
    assert!(is_promo_square(Player::Blue, Coord::new(10, 5)));
    assert!(is_promo_square(Player::Green, Coord::new(3, 5)));
    assert!(!is_promo_square(Player::Red, Coord::new(5, 9)));
}

#[test]
fn start_move_count_is_twenty() {
    let g = FourGame::new(Format::FreeForAll);
    // 8 pawns × 2 + 4 knight moves = 20.
    assert_eq!(g.legal_moves().len(), 20);
}

#[test]
fn pawns_advance_toward_centre() {
    let g = FourGame::new(Format::FreeForAll);
    let has = |ms: &[Move4], f: (i8, i8), t: (i8, i8)| {
        ms.iter()
            .any(|m| (m.from.col, m.from.row) == f && (m.to.col, m.to.row) == t)
    };
    let red = g.legal_moves_for(Player::Red);
    assert!(has(&red, (3, 1), (3, 2))); // Red up
    assert!(has(&red, (3, 1), (3, 3))); // double
    let blue = g.legal_moves_for(Player::Blue);
    assert!(has(&blue, (1, 3), (2, 3))); // Blue right
}

#[test]
fn capture_scores_in_ffa() {
    let mut g = FourGame::new(Format::FreeForAll);
    g.board.put(4, 2, Player::Blue, Piece::Pawn); // hanging foe for Red
    assert!(g.make_move(Move4::plain(Coord::new(3, 1), Coord::new(4, 2))));
    assert_eq!(g.scores[Player::Red.index()], 1);
    assert_eq!(at(&g, 4, 2), Some((Player::Red, Piece::Pawn)));
}

#[test]
fn cannot_capture_partner_in_teams() {
    let mut g = FourGame::new(Format::Teams);
    g.board.put(4, 2, Player::Yellow, Piece::Pawn); // Red's partner
    assert!(!g.make_move(Move4::plain(Coord::new(3, 1), Coord::new(4, 2))));
}

#[test]
fn bot_takes_a_hanging_queen() {
    let mut g = FourGame::new(Format::FreeForAll);
    g.board.put(4, 2, Player::Blue, Piece::Queen);
    let m = chess4::bot::greedy_move(&g, 7).unwrap();
    assert_eq!((m.to.col, m.to.row), (4, 2));
}

#[test]
fn difficulty_bot_codes_are_stable_and_always_choose_legal_moves() {
    let game = FourGame::new(Format::FreeForAll);
    for code in 0..=5 {
        let difficulty = chess4::bot::BotDifficulty::from_code(code).unwrap();
        assert_eq!(difficulty.code(), code);
        let selected = chess4::bot::move_for_difficulty(&game, difficulty, 17).unwrap();
        assert!(game.legal_moves().contains(&selected));
    }
    assert_eq!(chess4::bot::BotDifficulty::VeryEasy.target_elo(), Some(500));
    assert_eq!(
        chess4::bot::BotDifficulty::VeryHard.target_elo(),
        Some(2000)
    );
    assert_eq!(chess4::bot::BotDifficulty::Impossible.target_elo(), None);
    assert!(chess4::bot::BotDifficulty::from_code(6).is_none());
}

#[test]
fn normal_and_stronger_bots_notice_a_hanging_queen() {
    let mut game = FourGame::new(Format::FreeForAll);
    game.board.put(4, 2, Player::Blue, Piece::Queen);
    for difficulty in [
        chess4::bot::BotDifficulty::Normal,
        chess4::bot::BotDifficulty::Hard,
        chess4::bot::BotDifficulty::VeryHard,
        chess4::bot::BotDifficulty::Impossible,
    ] {
        let selected = chess4::bot::move_for_difficulty(&game, difficulty, 29).unwrap();
        assert_eq!(
            (selected.to.col, selected.to.row),
            (4, 2),
            "{difficulty:?} missed the free queen",
        );
    }
}

#[test]
fn normal_bot_considers_a_quiet_queen_escape_before_a_small_capture() {
    let mut game = FourGame::new(Format::FreeForAll);
    game.board = Board::empty();
    // Keep all four kings present and legal, then give Red a tempting pawn
    // capture while Blue's knight is about to take Red's queen. The queen must
    // move quietly; a capture-only root prefilter used to miss this class.
    game.board.put(6, 0, Player::Red, Piece::King);
    game.board.put(0, 7, Player::Blue, Piece::King);
    game.board.put(7, 13, Player::Yellow, Piece::King);
    game.board.put(13, 7, Player::Green, Piece::King);
    game.board.put(7, 4, Player::Red, Piece::Queen);
    game.board.put(3, 1, Player::Red, Piece::Pawn);
    game.board.put(4, 2, Player::Blue, Piece::Pawn);
    game.board.put(5, 5, Player::Blue, Piece::Knight); // attacks (7,4)

    let selected =
        chess4::bot::move_for_difficulty(&game, chess4::bot::BotDifficulty::Normal, 73).unwrap();
    assert_eq!(selected.from, Coord::new(7, 4));
    assert_ne!(selected.to, Coord::new(7, 4));
}

#[test]
fn slider_stops_at_a_cut_corner() {
    // A rook in the left arm sliding up the a-file must stop before the cut
    // top-left corner (rows 11..13 at col 0 are invalid).
    let mut g = FourGame::new(Format::FreeForAll);
    // Clear Blue's back rank so its a8-ish rook can roam; place a lone rook.
    g.board = Board::empty();
    g.board.put(7, 0, Player::Red, Piece::King); // kings so checks are well-defined
    g.board.put(7, 13, Player::Yellow, Piece::King);
    g.board.put(0, 5, Player::Red, Piece::Rook);
    let moves = g.legal_moves_for(Player::Red);
    // Rook at (0,5) going up the col-0 file: (0,6)..(0,10) valid, (0,11) is a cut
    // corner → not reachable.
    assert!(moves.iter().any(|m| (m.to.col, m.to.row) == (0, 10)));
    assert!(!moves.iter().any(|m| (m.to.col, m.to.row) == (0, 11)));
}

#[test]
fn turn_rotates_red_to_blue() {
    let mut g = FourGame::new(Format::FreeForAll);
    g.make_move(Move4::plain(Coord::new(3, 1), Coord::new(3, 2)));
    assert_eq!(g.turn, Player::Blue);
}

#[test]
fn teams_win_when_both_opponents_dead() {
    let mut g = FourGame::new(Format::Teams);
    g.status[Player::Blue.index()] = PlayerStatus::Checkmated;
    g.status[Player::Green.index()] = PlayerStatus::Checkmated;
    assert!(matches!(g.result(), FourResult::TeamWin(Team::RedYellow)));
}

#[test]
fn red_castles_kingside() {
    let mut g = FourGame::new(Format::FreeForAll);
    g.board.clear(8, 0); // bishop
    g.board.clear(9, 0); // knight
    let moves = g.legal_moves();
    let cm = moves
        .iter()
        .find(|m| m.castle && m.from == Coord::new(7, 0) && m.to == Coord::new(9, 0))
        .copied();
    assert!(cm.is_some(), "kingside castle should be legal");
    g.make_move(cm.unwrap());
    assert_eq!(at(&g, 9, 0), Some((Player::Red, Piece::King)));
    assert_eq!(at(&g, 8, 0), Some((Player::Red, Piece::Rook)));
}

#[test]
fn every_army_can_castle_toward_its_high_coordinate_rook() {
    // The four armies have different home-edge orientations. Exercise their
    // actual UCI-facing king/rook geometry rather than assuming Red's row
    // layout applies to the lateral armies too.
    let cases = [
        (
            Player::Red,
            Coord::new(7, 0),
            Coord::new(9, 0),
            Coord::new(8, 0),
            &[(8, 0), (9, 0)][..],
        ),
        (
            Player::Blue,
            Coord::new(0, 7),
            Coord::new(0, 9),
            Coord::new(0, 8),
            &[(0, 8), (0, 9)][..],
        ),
        (
            Player::Yellow,
            Coord::new(6, 13),
            Coord::new(8, 13),
            Coord::new(7, 13),
            &[(7, 13), (8, 13), (9, 13)][..],
        ),
        (
            Player::Green,
            Coord::new(13, 6),
            Coord::new(13, 8),
            Coord::new(13, 7),
            &[(13, 7), (13, 8), (13, 9)][..],
        ),
    ];

    for (player, king_from, king_to, rook_to, clear) in cases {
        let mut game = FourGame::new(Format::FreeForAll);
        game.turn = player;
        for &(col, row) in clear {
            game.board.clear(col, row);
        }
        let castle = game
            .legal_moves()
            .into_iter()
            .find(|m| m.castle && m.from == king_from && m.to == king_to)
            .unwrap_or_else(|| panic!("{player:?} should be able to castle"));
        assert!(game.make_move(castle));
        assert_eq!(
            at(&game, king_to.col, king_to.row),
            Some((player, Piece::King))
        );
        assert_eq!(
            at(&game, rook_to.col, rook_to.row),
            Some((player, Piece::Rook))
        );
    }
}

#[test]
fn blue_can_queue_a_castle_before_red_moves() {
    let mut game = FourGame::new(Format::FreeForAll);
    game.board.clear(0, 8); // Blue bishop
    game.board.clear(0, 9); // Blue knight

    // The game begins with Red to move. Blue should still be able to queue
    // the castle geometrically; it is fully revalidated when Blue's turn
    // arrives after Red moves.
    let blue_king = Coord::new(0, 7);
    let blue_castle_to = Coord::new(0, 9);
    assert!(game.premove_targets(blue_king).contains(&blue_castle_to));

    assert!(game.make_move(Move4::plain(Coord::new(3, 1), Coord::new(3, 2))));
    assert_eq!(game.turn, Player::Blue);
    let castle = game
        .legal_moves()
        .into_iter()
        .find(|m| m.castle && m.from == blue_king && m.to == blue_castle_to)
        .expect("Blue's queued castle must remain legal on its turn");
    assert!(game.make_move(castle));
    assert_eq!(at(&game, 0, 9), Some((Player::Blue, Piece::King)));
    assert_eq!(at(&game, 0, 8), Some((Player::Blue, Piece::Rook)));
}

#[test]
fn castling_revoked_after_king_moves() {
    let mut g = FourGame::new(Format::FreeForAll);
    g.board.clear(8, 0);
    g.board.clear(9, 0);
    g.make_move(Move4::plain(Coord::new(7, 0), Coord::new(8, 0))); // Ke1-ish move
    assert_eq!(g.castling[Player::Red.index()], [false, false]);
}

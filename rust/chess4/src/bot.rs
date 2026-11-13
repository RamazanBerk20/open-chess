//! Bounded four-player bot policies.
//!
//! Four-player chess has a different board and turn model from the 8x8 engine,
//! so this module deliberately keeps its own compact, deterministic search.
//! Every stronger level searches more opponent replies, but node budgets keep a
//! host-authoritative LAN turn responsive. The budgets count nodes only (never
//! wall-clock time), so a move is a pure function of position, level and seed.

use std::cmp::Reverse;

use crate::game::FourGame;
use crate::movegen::Move4;
use crate::types::{Format, Piece, Player, PlayerStatus};

/// Stable host-wire difficulty codes. They intentionally match the order of
/// the app's `Difficulty.presets`: 500, 800, 1000, 1500, 2000, then maximum
/// available four-player search strength.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BotDifficulty {
    VeryEasy,
    Easy,
    Normal,
    Hard,
    VeryHard,
    Impossible,
}

impl BotDifficulty {
    pub fn from_code(code: i32) -> Option<Self> {
        match code {
            0 => Some(Self::VeryEasy),
            1 => Some(Self::Easy),
            2 => Some(Self::Normal),
            3 => Some(Self::Hard),
            4 => Some(Self::VeryHard),
            5 => Some(Self::Impossible),
            _ => None,
        }
    }

    pub fn code(self) -> i32 {
        match self {
            Self::VeryEasy => 0,
            Self::Easy => 1,
            Self::Normal => 2,
            Self::Hard => 3,
            Self::VeryHard => 4,
            Self::Impossible => 5,
        }
    }

    /// Calibrated target band used by the app UI. `Impossible` is intentionally
    /// unbounded rather than claiming a numerical Elo.
    pub fn target_elo(self) -> Option<u16> {
        match self {
            Self::VeryEasy => Some(500),
            Self::Easy => Some(800),
            Self::Normal => Some(1000),
            Self::Hard => Some(1500),
            Self::VeryHard => Some(2000),
            Self::Impossible => None,
        }
    }
}

/// A simple greedy bot retained for local games and callers that only need a
/// fast tactical move: take the highest-value capture, else promote, else pick
/// a deterministic legal move.
pub fn greedy_move(game: &FourGame, seed: u64) -> Option<Move4> {
    let moves = game.legal_moves();
    if moves.is_empty() {
        return None;
    }
    let best_score = moves
        .iter()
        .map(|&m| move_heuristic(game, m))
        .max()
        .unwrap_or_default();
    let best: Vec<Move4> = moves
        .into_iter()
        .filter(|&m| move_heuristic(game, m) == best_score)
        .collect();
    Some(best[random_index(seed, best.len())])
}

/// Select a legal move with the requested LAN AI difficulty. The seed keeps
/// weak-level variety reproducible under the host authority.
pub fn move_for_difficulty(game: &FourGame, difficulty: BotDifficulty, seed: u64) -> Option<Move4> {
    match difficulty {
        // 500: deliberately broad legal play. It can miss captures and make
        // one-move mistakes, but always remains rule-valid.
        BotDifficulty::VeryEasy => {
            let moves = game.legal_moves();
            (!moves.is_empty()).then(|| moves[random_index(seed, moves.len())])
        }
        // 800: often wanders, but occasionally notices the obvious tactic.
        BotDifficulty::Easy => {
            let moves = game.legal_moves();
            if moves.is_empty() {
                None
            } else if next_random(seed) % 100 < 65 {
                Some(moves[random_index(seed, moves.len())])
            } else {
                greedy_move(game, seed)
            }
        }
        // Normal and above evaluate the current position after a bounded
        // number of sequential four-player replies. More replies and a larger
        // search budget create visibly stronger, less tactical-blind play.
        BotDifficulty::Normal => search_move(game, seed, 1, 5, 400),
        BotDifficulty::Hard => search_move(game, seed, 2, 6, 400),
        BotDifficulty::VeryHard => search_move(game, seed, 3, 6, 900),
        BotDifficulty::Impossible => search_move(game, seed, 4, 6, 1_700),
    }
}

/// Material/tactical ordering before the more expensive positional evaluator.
/// Captures dominate promotions because avoiding immediate material loss is
/// the strongest signal available without an unbounded search.
fn move_heuristic(game: &FourGame, m: Move4) -> i64 {
    let mut score = 0_i64;
    if let Some((_, captured)) = game.board.get(m.to.col, m.to.row) {
        score += piece_value(captured) * 100;
    }
    if let Some(promoted) = m.promo {
        score += 500 + piece_value(promoted) * 10;
    }
    if m.castle {
        score += 35;
    }
    score
}

fn piece_value(piece: Piece) -> i64 {
    match piece {
        Piece::Pawn => 100,
        Piece::Knight => 320,
        Piece::Bishop => 330,
        Piece::Rook => 500,
        Piece::Queen => 900,
        Piece::King => 0,
    }
}

/// A tiny deterministic RNG is enough for reproducible weak moves and tied
/// candidate selection without adding a second random dependency to chess4.
fn next_random(seed: u64) -> u64 {
    seed.wrapping_mul(6_364_136_223_846_793_005)
        .wrapping_add(1_442_695_040_888_963_407)
}

fn random_index(seed: u64, len: usize) -> usize {
    debug_assert!(len > 0);
    ((next_random(seed) >> 33) as usize) % len
}

struct SearchBudget {
    nodes: usize,
    max_nodes: usize,
}

impl SearchBudget {
    fn new(max_nodes: usize) -> Self {
        Self {
            nodes: 0,
            max_nodes,
        }
    }

    fn exhausted(&self) -> bool {
        self.nodes >= self.max_nodes
    }

    fn visit(&mut self) {
        self.nodes = self.nodes.saturating_add(1);
    }
}

/// Return high-potential legal moves ordered for a non-root actor's goal. A
/// tactical prefilter keeps the deeper reply tree bounded; root selection is
/// deliberately separate so a quiet defensive move cannot vanish before it is
/// searched.
fn ordered_candidates(
    game: &FourGame,
    root: Player,
    maximize_root: bool,
    limit: usize,
) -> Vec<Move4> {
    let mut moves = game.legal_moves();
    moves.sort_by_key(|move_| Reverse(move_heuristic(game, *move_)));
    moves.truncate(limit.saturating_mul(2).max(limit));

    let mut evaluated = Vec::with_capacity(moves.len());
    for m in moves {
        let mut next = game.clone();
        if next.make_generated_move(m) {
            evaluated.push((evaluate(&next, root), m));
        }
    }
    evaluated.sort_by(|(left, _), (right, _)| {
        if maximize_root {
            right.cmp(left)
        } else {
            left.cmp(right)
        }
    });
    evaluated.truncate(limit);
    evaluated.into_iter().map(|(_, m)| m).collect()
}

/// Largest legal immediate capture against the root player/team. This makes a
/// move that saves a hanging queen, rook, or partner piece rank ahead of a
/// shallow material grab before reply search confirms it.
fn immediate_root_threat(game: &FourGame, root: Player) -> i64 {
    if is_root_ally(game.format, root, game.turn) {
        return 0;
    }
    game.legal_moves()
        .into_iter()
        .filter_map(|m| {
            let (owner, piece) = game.board.get(m.to.col, m.to.row)?;
            is_root_ally(game.format, root, owner).then_some(piece_value(piece))
        })
        .max()
        .unwrap_or_default()
}

fn root_candidate_score(game: &FourGame, root: Player) -> i64 {
    // Scale the one-move threat above normal positional drift. The full reply
    // search still decides the move, but this ordering gets quiet saves into a
    // small Normal-level time budget rather than leaving them behind captures.
    evaluate(game, root) - immediate_root_threat(game, root) * 2
}

/// Evaluate every legal root move until the fixed budget expires. Unlike
/// [`ordered_candidates`], this intentionally has no capture-only truncation:
/// quiet defensive moves stay eligible at Normal and above, and Impossible
/// scores every legal root candidate that fits in its deadline.
fn root_candidates(game: &FourGame, root: Player, budget: &mut SearchBudget) -> Vec<Move4> {
    let mut evaluated = Vec::new();
    for m in game.legal_moves() {
        if budget.exhausted() && !evaluated.is_empty() {
            break;
        }
        budget.visit();
        let mut next = game.clone();
        if next.make_generated_move(m) {
            evaluated.push((root_candidate_score(&next, root), m));
        }
    }
    evaluated.sort_by(|(left, _), (right, _)| right.cmp(left));
    evaluated.into_iter().map(|(_, m)| m).collect()
}

fn is_root_ally(format: Format, root: Player, actor: Player) -> bool {
    match format {
        Format::Teams => actor.team() == root.team(),
        Format::FreeForAll => actor == root,
    }
}

/// A root-relative evaluation suitable for both free-for-all and teams. It is
/// intentionally cheap: score totals and surviving material dominate, while
/// an eliminated player is a decisive loss for that player/team.
fn evaluate(game: &FourGame, root: Player) -> i64 {
    let player_value = |player: Player| {
        let mut value = i64::from(game.scores[player.index()]) * 120;
        for cell in game.board.cells.iter().flatten() {
            if cell.0 == player {
                value += piece_value(cell.1);
            }
        }
        match game.status[player.index()] {
            PlayerStatus::Active => {
                if game.in_check(player) {
                    value -= 45;
                }
            }
            PlayerStatus::Checkmated | PlayerStatus::Stalemated | PlayerStatus::Resigned => {
                value -= 50_000;
            }
        }
        value
    };

    match game.format {
        Format::Teams => {
            let mut friendly = 0;
            let mut opposing = 0;
            for player in Player::ALL {
                if player.team() == root.team() {
                    friendly += player_value(player);
                } else {
                    opposing += player_value(player);
                }
            }
            friendly - opposing
        }
        Format::FreeForAll => {
            let root_value = player_value(root);
            let strongest_opponent = Player::ALL
                .into_iter()
                .filter(|&player| player != root)
                .map(player_value)
                .max()
                .unwrap_or_default();
            root_value - strongest_opponent
        }
    }
}

fn bounded_search(
    game: &FourGame,
    root: Player,
    remaining_plies: u8,
    branch_limit: usize,
    budget: &mut SearchBudget,
) -> i64 {
    if remaining_plies == 0 || game.ended || budget.exhausted() {
        return evaluate(game, root);
    }
    budget.visit();
    let maximize_root = is_root_ally(game.format, root, game.turn);
    let moves = ordered_candidates(game, root, maximize_root, branch_limit);
    if moves.is_empty() {
        return evaluate(game, root);
    }

    let mut best = if maximize_root { i64::MIN } else { i64::MAX };
    for m in moves {
        if budget.exhausted() {
            break;
        }
        let mut next = game.clone();
        if !next.make_generated_move(m) {
            continue;
        }
        let score = bounded_search(&next, root, remaining_plies - 1, branch_limit, budget);
        if maximize_root {
            best = best.max(score);
        } else {
            best = best.min(score);
        }
    }
    if best == i64::MIN || best == i64::MAX {
        evaluate(game, root)
    } else {
        best
    }
}

fn search_move(
    game: &FourGame,
    seed: u64,
    reply_plies: u8,
    branch_limit: usize,
    max_nodes: usize,
) -> Option<Move4> {
    let root = game.turn;
    let mut budget = SearchBudget::new(max_nodes);
    let candidates = root_candidates(game, root, &mut budget);
    if candidates.is_empty() {
        return None;
    }
    let mut best_score = i64::MIN;
    let mut best_moves = Vec::new();
    for m in candidates {
        if budget.exhausted() && !best_moves.is_empty() {
            break;
        }
        let mut next = game.clone();
        if !next.make_generated_move(m) {
            continue;
        }
        let score = bounded_search(&next, root, reply_plies, branch_limit, &mut budget);
        if score > best_score {
            best_score = score;
            best_moves.clear();
            best_moves.push(m);
        } else if score == best_score {
            best_moves.push(m);
        }
    }
    (!best_moves.is_empty()).then(|| best_moves[random_index(seed, best_moves.len())])
}

#[cfg(test)]
mod tests {
    use super::{root_candidates, SearchBudget};
    use crate::board::Board;
    use crate::{Format, FourGame, Piece, Player};

    #[test]
    fn root_candidates_keep_every_legal_quiet_move_within_budget() {
        let mut game = FourGame::new(Format::FreeForAll);
        game.board = Board::empty();
        game.board.put(6, 0, Player::Red, Piece::King);
        game.board.put(0, 7, Player::Blue, Piece::King);
        game.board.put(7, 13, Player::Yellow, Piece::King);
        game.board.put(13, 7, Player::Green, Piece::King);
        game.board.put(7, 4, Player::Red, Piece::Queen);

        let legal_count = game.legal_moves().len();
        assert!(legal_count > 32, "position must exceed the old root cap");
        let mut budget = SearchBudget::new(10_000);
        let candidates = root_candidates(&game, Player::Red, &mut budget);
        assert_eq!(candidates.len(), legal_count);
    }
}

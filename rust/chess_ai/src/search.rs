//! Negamax + alpha-beta search with iterative deepening, quiescence, a Zobrist
//! transposition table and move ordering (hash → MVV-LVA → killers → history).
//!
//! Pure: time is read via `std::time::Instant`, and cancellation is a caller
//! supplied `Fn() -> bool` predicate, so no bridge types leak in here.

use std::time::{Duration, Instant};

use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};

use chess_core::types::Piece;
use chess_core::{Move, MoveList, Position};

use crate::eval::{evaluate, MATE, MATE_THRESHOLD};

const INF: i32 = 50_000;
const MAX_PLY: usize = 64;
const PVAL: [i32; 6] = [100, 320, 330, 500, 900, 20_000];

/// Upper bound for the post-search candidate ranking. Lower skill levels only
/// need a shallow, tactical-safe choice set; running a full second search for
/// every legal root move would make weak play slower than strong play.
const CANDIDATE_MAX_DEPTH: u8 = 5;

const BOUND_EXACT: u8 = 0;
const BOUND_LOWER: u8 = 1;
const BOUND_UPPER: u8 = 2;

#[derive(Clone, Copy)]
struct TtEntry {
    key: u64,
    depth: i16,
    score: i32,
    flag: u8,
    best: Option<Move>,
}

impl Default for TtEntry {
    fn default() -> Self {
        TtEntry {
            key: 0,
            depth: -1,
            score: 0,
            flag: BOUND_EXACT,
            best: None,
        }
    }
}

/// Search bounds. `move_time_ms == None` means depth-limited only.
#[derive(Clone, Copy, Debug)]
pub struct SearchLimits {
    pub max_depth: u8,
    pub move_time_ms: Option<u64>,
}

/// Difficulty configuration. Weakness is bounded: a level may vary among
/// evaluated candidates, but cannot deliberately choose a move outside its
/// centipawn-loss budget or a move that loses by force when a safe move exists.
#[derive(Clone, Copy, Debug)]
pub struct AiConfig {
    pub max_depth: u8,
    pub move_time_ms: Option<u64>,
    /// Maximum allowed root-score loss from the strongest evaluated candidate.
    pub max_eval_loss_cp: i32,
    /// Probability (0..1) of varying among eligible candidates.
    pub random_move_chance: f32,
    /// Depth used to rank candidates after the main search completes.
    pub candidate_depth: u8,
    /// Draw aversion in centipawns (positive = avoid draws).
    pub contempt: i32,
    /// RNG seed for reproducible weakening.
    pub seed: u64,
}

impl Default for AiConfig {
    fn default() -> Self {
        AiConfig {
            max_depth: 8,
            move_time_ms: Some(1000),
            max_eval_loss_cp: 0,
            random_move_chance: 0.0,
            candidate_depth: 3,
            contempt: 0,
            seed: 0,
        }
    }
}

/// Result of (an iteration of) the search.
#[derive(Clone, Debug, Default)]
pub struct SearchInfo {
    pub depth: u8,
    pub score_cp: i32,
    pub nodes: u64,
    pub best: Option<Move>,
    pub pv: Vec<Move>,
}

pub struct Engine {
    tt: Vec<TtEntry>,
    mask: usize,
    killers: [[Option<Move>; 2]; MAX_PLY],
    history: [[i32; 64]; 64],
    nodes: u64,
    stop: bool,
    deadline: Option<Instant>,
    contempt: i32,
    /// Position hashes along the current search line (for repetition detection).
    path: Vec<u64>,
    /// Position hashes from the actual game before the root (for repetition).
    game_hist: Vec<u64>,
}

impl Engine {
    /// Create an engine with a transposition table of `2^bits` entries.
    pub fn new(tt_bits: u32) -> Engine {
        let size = 1usize << tt_bits;
        Engine {
            tt: vec![TtEntry::default(); size],
            mask: size - 1,
            killers: [[None; 2]; MAX_PLY],
            history: [[0; 64]; 64],
            nodes: 0,
            stop: false,
            deadline: None,
            contempt: 0,
            path: Vec::with_capacity(MAX_PLY),
            game_hist: Vec::new(),
        }
    }

    /// Provide the actual game's position-hash history so the search treats a
    /// return to an earlier game position as a draw (repetition avoidance).
    pub fn set_game_history(&mut self, history: &[u64]) {
        self.game_hist = history.to_vec();
    }

    fn is_draw_by_repetition(&self, hash: u64) -> bool {
        // A repeat within the current search line is a draw (the side can force
        // the third occurrence). Against the actual game history, require a true
        // threefold: the position must already have occurred twice, so this is
        // the third — otherwise a single earlier occurrence would be mis-scored
        // as a draw, dodging winning moves / over-valuing lost lines.
        if self.path.contains(&hash) {
            return true;
        }
        self.game_hist.iter().filter(|&&h| h == hash).count() >= 2
    }

    /// Draw score from the perspective of the side to move at `ply`, sized so
    /// the *root* side always sees a draw as `-contempt` (contempt > 0 = draw
    /// aversion) no matter the ply parity at which the draw is detected. A flat
    /// `-contempt` would invert at odd plies, making the engine seek draws.
    #[inline]
    fn draw_score(&self, ply: usize) -> i32 {
        if ply.is_multiple_of(2) {
            -self.contempt
        } else {
            self.contempt
        }
    }

    /// Full-strength iterative-deepening search.
    pub fn search(
        &mut self,
        root: &Position,
        limits: SearchLimits,
        cancel: &dyn Fn() -> bool,
        on_info: impl FnMut(&SearchInfo),
    ) -> SearchInfo {
        self.contempt = 0;
        self.run(root, limits, cancel, on_info)
    }

    /// Search with a bounded difficulty policy. The main search always finds the
    /// best line first; only then can a weaker level vary within a safe score
    /// band. This keeps Normal and above from making obvious one-move blunders.
    pub fn search_with_config(
        &mut self,
        root: &Position,
        config: AiConfig,
        cancel: &dyn Fn() -> bool,
        on_info: impl FnMut(&SearchInfo),
    ) -> SearchInfo {
        self.contempt = config.contempt;
        let mut rng = StdRng::seed_from_u64(config.seed);
        let will_vary = config.max_eval_loss_cp > 0
            && config.random_move_chance > 0.0
            && rng.random::<f32>() < config.random_move_chance.clamp(0.0, 1.0);
        // A deliberate variation must fit inside the level's total move budget.
        // Reserve its small candidate pass before the primary search starts;
        // otherwise a weak move could take up to 33% longer than advertised.
        let selection_ms = config.move_time_ms.map(|ms| (ms / 3).clamp(50, 750));
        let primary_time_ms = if will_vary {
            config
                .move_time_ms
                .map(|ms| ms.saturating_sub(selection_ms.unwrap_or(0)).max(1))
        } else {
            config.move_time_ms
        };
        let limits = SearchLimits {
            max_depth: config.max_depth,
            move_time_ms: primary_time_ms,
        };
        let info = self.run(root, limits, cancel, on_info);

        if !will_vary {
            return info;
        }

        // Candidate ranking is deliberately capped and gets a small separate
        // budget. If it cannot finish, return the full search's best move.
        let depth = info
            .depth
            .min(config.candidate_depth.clamp(1, CANDIDATE_MAX_DEPTH))
            .max(1);
        let candidate_ms = selection_ms.map(|ms| (ms / 2).max(25));
        let verification_ms =
            selection_ms.map(|ms| ms.saturating_sub(candidate_ms.unwrap_or(0)).max(25));
        self.stop = false;
        self.deadline = candidate_ms.map(|ms| Instant::now() + Duration::from_millis(ms));
        let mut scored = self.root_scores(root, depth, cancel);
        if self.stop || scored.is_empty() {
            return info;
        }

        if let Some(best) = info.best {
            // The main search can see deeper than the candidate pass. Keep its
            // principal move available even when the shallow order differs.
            if !scored.iter().any(|(mv, _)| *mv == best) {
                scored.push((best, info.score_cp));
                scored.sort_by_key(|x| std::cmp::Reverse(x.1));
            }
        }
        let book_candidates: Vec<Move> = crate::opening::book_moves_if_ready(root)
            .into_iter()
            .filter_map(|uci| root.clone().parse_uci(&uci).ok())
            .collect();
        // The full-strength result remains the default. Candidate ranking only
        // exists to select a deliberate, bounded variation; replacing the
        // principal variation with the shallow candidate winner even when the
        // RNG did not fire made Normal+ routinely play below their configured
        // depth.
        let Some((mv, _shallow_score)) =
            select_safe_candidate(&scored, &book_candidates, &config, &mut rng)
        else {
            return info;
        };
        if info.best == Some(mv) {
            return info;
        }
        // Candidate ranking is intentionally shallow for speed, but it must
        // never be trusted as the final safety boundary. Re-search the one
        // selected move at the same completed depth as the main PV; otherwise
        // Normal can pick a move whose tactic only appears past candidate depth.
        self.stop = false;
        self.deadline = verification_ms.map(|ms| Instant::now() + Duration::from_millis(ms));
        let Some(score) = self.root_move_score(root, mv, info.depth.max(1), cancel) else {
            return info;
        };
        if !within_loss_budget(info.score_cp, score, config.max_eval_loss_cp) {
            return info;
        }
        SearchInfo {
            depth: info.depth,
            score_cp: score,
            nodes: info.nodes,
            best: Some(mv),
            pv: vec![mv],
        }
    }

    /// Score every root move at `depth` with a full window (for weakening).
    fn root_scores(
        &mut self,
        root: &Position,
        depth: u8,
        cancel: &dyn Fn() -> bool,
    ) -> Vec<(Move, i32)> {
        let mut pos = root.clone();
        let moves = pos.generate_legal();
        let mut out = Vec::new();
        self.path.clear();
        self.path.push(pos.hash);
        for i in 0..moves.len() {
            let mv = moves[i];
            let u = pos.make_move(mv);
            let score = -self.negamax(&mut pos, depth as i32 - 1, -INF, INF, 1, cancel);
            pos.unmake_move(mv, u);
            if self.stop {
                break;
            }
            out.push((mv, score));
        }
        out.sort_by_key(|x| std::cmp::Reverse(x.1));
        out
    }

    /// Re-evaluate one candidate at the full completed root depth. Returning
    /// `None` on cancellation/deadline deliberately preserves the PV instead
    /// of guessing about the candidate's tactical safety.
    fn root_move_score(
        &mut self,
        root: &Position,
        mv: Move,
        depth: u8,
        cancel: &dyn Fn() -> bool,
    ) -> Option<i32> {
        let mut pos = root.clone();
        let legal = pos.generate_legal();
        if !(0..legal.len()).any(|index| legal[index] == mv) {
            return None;
        }
        self.path.clear();
        self.path.push(pos.hash);
        let undo = pos.make_move(mv);
        let score = -self.negamax(&mut pos, depth as i32 - 1, -INF, INF, 1, cancel);
        pos.unmake_move(mv, undo);
        self.path.clear();
        (!self.stop).then_some(score)
    }

    fn run(
        &mut self,
        root: &Position,
        limits: SearchLimits,
        cancel: &dyn Fn() -> bool,
        mut on_info: impl FnMut(&SearchInfo),
    ) -> SearchInfo {
        self.killers = [[None; 2]; MAX_PLY];
        self.history = [[0; 64]; 64];
        self.nodes = 0;
        self.stop = false;
        self.path.clear();
        self.deadline = limits
            .move_time_ms
            .map(|ms| Instant::now() + Duration::from_millis(ms));

        // Variant wins are represented by a position that may still have
        // pseudo-legal moves (three-check, hill, atomic, Fog). At a root such
        // a position is already over and the side to move lost on the prior
        // ply, so never return a spurious legal move or static evaluation.
        if root.variant_terminal().is_some() {
            return SearchInfo {
                depth: 0,
                score_cp: -MATE,
                nodes: 0,
                best: None,
                pv: Vec::new(),
            };
        }

        // Fallback so we always return a legal move.
        let mut work = root.clone();
        let legal = work.generate_legal();
        let mut result = SearchInfo {
            depth: 0,
            score_cp: 0,
            nodes: 0,
            best: if legal.is_empty() {
                None
            } else {
                Some(legal[0])
            },
            pv: Vec::new(),
        };
        if legal.is_empty() {
            return result;
        }

        let max_depth = limits.max_depth.max(1).min(MAX_PLY as u8 - 1);
        for depth in 1..=max_depth {
            let mut pos = root.clone();
            let prior = result.score_cp;
            let use_aspiration =
                is_standard_search(root) && depth > 1 && prior.abs() < MATE_THRESHOLD;
            let (mut alpha, mut beta) = if use_aspiration {
                (prior - 50, prior + 50)
            } else {
                (-INF, INF)
            };
            let mut score = self.negamax(&mut pos, depth as i32, alpha, beta, 0, cancel);
            if !self.stop && use_aspiration && (score <= alpha || score >= beta) {
                pos = root.clone();
                alpha = -INF;
                beta = INF;
                score = self.negamax(&mut pos, depth as i32, alpha, beta, 0, cancel);
            }
            if self.stop {
                break; // discard the incomplete iteration, keep the last result
            }
            let best = self
                .tt_probe(root.hash)
                .and_then(|e| e.best)
                .or(result.best);
            let pv = self.extract_pv(root, depth as usize);
            result = SearchInfo {
                depth,
                score_cp: score,
                nodes: self.nodes,
                best,
                pv,
            };
            on_info(&result);
            if score.abs() >= MATE_THRESHOLD {
                break; // forced mate found
            }
        }
        result
    }

    fn negamax(
        &mut self,
        pos: &mut Position,
        depth: i32,
        mut alpha: i32,
        beta: i32,
        ply: usize,
        cancel: &dyn Fn() -> bool,
    ) -> i32 {
        self.nodes += 1;
        if self.nodes & 2047 == 0 && self.timed_out(cancel) {
            self.stop = true;
        }
        if self.stop {
            return 0;
        }
        // Draw by repetition or fifty-move: score as a draw so a winning engine
        // makes progress instead of shuffling (contempt = draw aversion).
        if ply > 0 && (pos.halfmove >= 100 || self.is_draw_by_repetition(pos.hash)) {
            return self.draw_score(ply);
        }
        // Variant loss (opponent reached three checks / the hill / blew up our
        // king): the side to move has lost.
        if ply > 0 && pos.variant_terminal().is_some() {
            return -MATE + ply as i32;
        }
        if depth <= 0 {
            return self.quiescence(pos, alpha, beta, ply, cancel);
        }

        let key = pos.hash;
        let mut tt_best = None;
        if let Some(e) = self.tt_probe(key) {
            tt_best = e.best;
            if e.depth as i32 >= depth {
                let s = adjust_from_tt(e.score, ply);
                match e.flag {
                    BOUND_EXACT => return s,
                    BOUND_LOWER if s >= beta => return s,
                    BOUND_UPPER if s <= alpha => return s,
                    _ => {}
                }
            }
        }

        let mut moves = pos.generate_legal();
        if moves.is_empty() {
            return if pos.in_check(pos.side) {
                -MATE + ply as i32
            } else {
                self.draw_score(ply) // stalemate (draw); contempt = draw aversion
            };
        }
        self.order_moves(pos, &mut moves, tt_best, ply);
        if ply == 0 {
            // The complete opening corpus is a search-order preference, never
            // a bypass of evaluation. This lets every level, including
            // Impossible, efficiently follow sound book continuations while a
            // tactical refutation can still win the full search.
            self.prefer_root_book_moves(pos, &mut moves, tt_best);
        }

        let alpha_orig = alpha;
        let mut best_score = -INF;
        let mut best_move = None;
        self.path.push(pos.hash);
        let standard_search = is_standard_search(pos);
        for i in 0..moves.len() {
            let mv = moves[i];
            let u = pos.make_move(mv);
            let quiet = !mv.is_capture() && !pos.in_check(pos.side);
            let reduced = standard_search && depth >= 3 && i >= 4 && quiet;
            let child_depth = if reduced { depth - 2 } else { depth - 1 };
            let mut score = if standard_search && i > 0 && depth > 1 {
                // Principal-variation search: a null window cheaply rejects
                // non-principal moves, then re-searches only genuine contenders.
                -self.negamax(pos, child_depth, -alpha - 1, -alpha, ply + 1, cancel)
            } else {
                -self.negamax(pos, child_depth, -beta, -alpha, ply + 1, cancel)
            };
            let needs_research = (standard_search && i > 0 && score > alpha && score < beta)
                || (reduced && score > alpha);
            if !self.stop && needs_research {
                score = -self.negamax(pos, depth - 1, -beta, -alpha, ply + 1, cancel);
            }
            pos.unmake_move(mv, u);
            if self.stop {
                self.path.pop();
                return 0;
            }
            if score > best_score {
                best_score = score;
                best_move = Some(mv);
            }
            if score > alpha {
                alpha = score;
            }
            if alpha >= beta {
                if !mv.is_capture() {
                    self.store_killer(ply, mv);
                    self.history[mv.from() as usize][mv.to() as usize] += depth * depth;
                }
                break;
            }
        }
        self.path.pop();

        let flag = if best_score <= alpha_orig {
            BOUND_UPPER
        } else if best_score >= beta {
            BOUND_LOWER
        } else {
            BOUND_EXACT
        };
        self.tt_store(key, depth, adjust_to_tt(best_score, ply), flag, best_move);
        best_score
    }

    fn quiescence(
        &mut self,
        pos: &mut Position,
        mut alpha: i32,
        beta: i32,
        ply: usize,
        cancel: &dyn Fn() -> bool,
    ) -> i32 {
        self.nodes += 1;
        if self.nodes & 2047 == 0 && self.timed_out(cancel) {
            self.stop = true;
        }
        if self.stop {
            return 0;
        }
        if ply > 0 && (pos.halfmove >= 100 || self.is_draw_by_repetition(pos.hash)) {
            return self.draw_score(ply);
        }
        if ply > 0 && pos.variant_terminal().is_some() {
            return -MATE + ply as i32;
        }

        // When in check we cannot "stand pat": search all evasions, else only
        // captures (with a stand-pat lower bound). This avoids the horizon
        // effect hiding a forced mate behind quiet check evasions.
        let in_check = pos.in_check(pos.side);
        if !in_check {
            let stand = evaluate(pos);
            if stand >= beta {
                return beta;
            }
            if stand > alpha {
                alpha = stand;
            }
        }
        if ply >= MAX_PLY - 1 {
            return evaluate(pos);
        }

        let mut moves = if in_check {
            pos.generate_legal()
        } else {
            capture_moves(pos)
        };
        if in_check && moves.is_empty() {
            return -MATE + ply as i32; // checkmate
        }
        self.order_captures(pos, &mut moves);
        for i in 0..moves.len() {
            let mv = moves[i];
            let u = pos.make_move(mv);
            let score = -self.quiescence(pos, -beta, -alpha, ply + 1, cancel);
            pos.unmake_move(mv, u);
            if self.stop {
                return 0;
            }
            if score >= beta {
                return beta;
            }
            if score > alpha {
                alpha = score;
            }
        }
        alpha
    }

    fn order_moves(&self, pos: &Position, moves: &mut MoveList, tt_best: Option<Move>, ply: usize) {
        let killers = self.killers[ply];
        let hist = &self.history;
        let score = |m: Move| -> i32 {
            if Some(m) == tt_best {
                return 2_000_000;
            }
            if m.is_capture() {
                return 1_000_000 + capture_value(pos, m) * 16 - mover_value(pos, m);
            }
            if Some(m) == killers[0] {
                return 900_000;
            }
            if Some(m) == killers[1] {
                return 800_000;
            }
            hist[m.from() as usize][m.to() as usize]
        };
        moves
            .as_mut_slice()
            .sort_by_key(|m| std::cmp::Reverse(score(*m)));
    }

    fn order_captures(&self, pos: &Position, moves: &mut MoveList) {
        let score = |m: Move| capture_value(pos, m) * 16 - mover_value(pos, m);
        moves
            .as_mut_slice()
            .sort_by_key(|m| std::cmp::Reverse(score(*m)));
    }

    /// Keep a previous iterative-deepening principal move first, then search
    /// legal opening-book continuations before ordinary moves at the root.
    /// Stable sorting preserves the normal tactical/history ordering within
    /// each group and does not affect non-Standard variants.
    fn prefer_root_book_moves(&self, pos: &Position, moves: &mut MoveList, tt_best: Option<Move>) {
        let book: Vec<Move> = crate::opening::book_moves_if_ready(pos)
            .into_iter()
            .filter_map(|uci| pos.clone().parse_uci(&uci).ok())
            .collect();
        if book.is_empty() {
            return;
        }
        moves.as_mut_slice().sort_by_key(|mv| {
            (
                Some(*mv) != tt_best,
                !book.iter().any(|candidate| candidate == mv),
            )
        });
    }

    fn store_killer(&mut self, ply: usize, mv: Move) {
        if self.killers[ply][0] != Some(mv) {
            self.killers[ply][1] = self.killers[ply][0];
            self.killers[ply][0] = Some(mv);
        }
    }

    #[inline]
    fn tt_probe(&self, key: u64) -> Option<TtEntry> {
        let e = self.tt[(key as usize) & self.mask];
        if e.key == key && e.depth >= 0 {
            Some(e)
        } else {
            None
        }
    }

    #[inline]
    fn tt_store(&mut self, key: u64, depth: i32, score: i32, flag: u8, best: Option<Move>) {
        let slot = (key as usize) & self.mask;
        let e = &mut self.tt[slot];
        // Depth-preferred replacement.
        if e.key != key || (depth as i16) >= e.depth {
            *e = TtEntry {
                key,
                depth: depth as i16,
                score,
                flag,
                best,
            };
        }
    }

    fn extract_pv(&self, root: &Position, max: usize) -> Vec<Move> {
        let mut pv = Vec::new();
        let mut pos = root.clone();
        for _ in 0..max {
            // Stop at a variant-terminal node (e.g. a king captured in Fog of
            // War / Atomic) — the game is over, don't walk past it.
            if pos.variant_terminal().is_some() {
                break;
            }
            let Some(e) = self.tt_probe(pos.hash) else {
                break;
            };
            let Some(mv) = e.best else { break };
            let legal = pos.generate_legal();
            if (0..legal.len()).any(|i| legal[i] == mv) {
                pv.push(mv);
                pos.make_move(mv);
            } else {
                break;
            }
        }
        pv
    }

    #[inline]
    fn timed_out(&self, cancel: &dyn Fn() -> bool) -> bool {
        cancel() || self.deadline.is_some_and(|d| Instant::now() >= d)
    }
}

/// Pick only candidates inside the configured loss budget. A forced mate loss
/// is never considered eligible unless the best move also loses by force.
fn select_safe_candidate(
    scored: &[(Move, i32)],
    book_candidates: &[Move],
    config: &AiConfig,
    rng: &mut StdRng,
) -> Option<(Move, i32)> {
    let (_, best_score) = scored[0];
    let floor = best_score.saturating_sub(config.max_eval_loss_cp.max(0));
    let best_is_lost = best_score <= -MATE_THRESHOLD;
    let eligible: Vec<(Move, i32)> = scored
        .iter()
        .copied()
        .filter(|(_, score)| *score >= floor && (best_is_lost || *score > -MATE_THRESHOLD))
        .collect();
    if eligible.len() <= 1 {
        return None;
    }
    // Opening lines are preferred only after the same safety filter as every
    // other move. The corpus deliberately contains gambits, so it is never a
    // free pass around the level's centipawn-loss budget.
    let book_eligible: Vec<(Move, i32)> = eligible
        .iter()
        .copied()
        .filter(|(mv, _)| book_candidates.contains(mv))
        .collect();
    let pool = if book_eligible.is_empty() {
        &eligible
    } else {
        &book_eligible
    };
    Some(pool[rng.random_range(0..pool.len())])
}

/// A candidate may only replace the full-strength PV when its independently
/// verified score stays in the configured loss band and does not introduce a
/// forced loss the PV avoids.
fn within_loss_budget(best_score: i32, candidate_score: i32, max_loss_cp: i32) -> bool {
    candidate_score >= best_score.saturating_sub(max_loss_cp.max(0))
        && (best_score <= -MATE_THRESHOLD || candidate_score > -MATE_THRESHOLD)
}

#[inline]
fn is_standard_search(pos: &Position) -> bool {
    matches!(
        pos.variant,
        chess_core::Variant::Standard | chess_core::Variant::Chess960
    )
}

/// Convert a node-relative mate score into a TT-stored (root-relative) score.
#[inline]
fn adjust_to_tt(score: i32, ply: usize) -> i32 {
    if score >= MATE_THRESHOLD {
        score + ply as i32
    } else if score <= -MATE_THRESHOLD {
        score - ply as i32
    } else {
        score
    }
}

/// Convert a TT-stored mate score back to node-relative.
#[inline]
fn adjust_from_tt(score: i32, ply: usize) -> i32 {
    if score >= MATE_THRESHOLD {
        score - ply as i32
    } else if score <= -MATE_THRESHOLD {
        score + ply as i32
    } else {
        score
    }
}

fn capture_moves(pos: &mut Position) -> MoveList {
    let all = pos.generate_legal();
    let mut caps = MoveList::new();
    for i in 0..all.len() {
        if all[i].is_capture() {
            caps.push(all[i]);
        }
    }
    caps
}

#[inline]
fn capture_value(pos: &Position, m: Move) -> i32 {
    if m.is_ep() {
        PVAL[Piece::Pawn.index()]
    } else {
        match pos.piece_at(m.to()) {
            Some((_, p)) => PVAL[p.index()],
            None => 0,
        }
    }
}

#[inline]
fn mover_value(pos: &Position, m: Move) -> i32 {
    match pos.piece_at(m.from()) {
        Some((_, p)) => PVAL[p.index()],
        None => 0,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bounded_selection_never_picks_a_forced_loss_when_safe_moves_exist() {
        let mut pos = Position::startpos();
        let best = pos.parse_uci("e2e4").unwrap();
        let safe = pos.parse_uci("d2d4").unwrap();
        let losing = pos.parse_uci("f2f3").unwrap();
        let cfg = AiConfig {
            max_depth: 2,
            move_time_ms: None,
            max_eval_loss_cp: 120,
            random_move_chance: 1.0,
            candidate_depth: 2,
            contempt: 0,
            seed: 9,
        };
        let scored = [(best, 20), (safe, -80), (losing, -MATE + 3)];
        let mut rng = StdRng::seed_from_u64(cfg.seed);
        let (selected, _) = select_safe_candidate(&scored, &[], &cfg, &mut rng).unwrap();
        assert!(selected == best || selected == safe);
    }

    #[test]
    fn a_single_safe_candidate_does_not_vary() {
        let mut pos = Position::startpos();
        let best = pos.parse_uci("e2e4").unwrap();
        let safe = pos.parse_uci("d2d4").unwrap();
        let cfg = AiConfig {
            max_depth: 5,
            move_time_ms: None,
            max_eval_loss_cp: 100,
            random_move_chance: 1.0,
            candidate_depth: 4,
            contempt: 0,
            seed: 1,
        };
        let mut rng = StdRng::seed_from_u64(cfg.seed);
        assert!(select_safe_candidate(&[(safe, 10), (best, -200)], &[], &cfg, &mut rng).is_none());
    }

    #[test]
    fn root_ordering_prefers_embedded_book_moves() {
        // Search-side lookup is deliberately non-initializing; make this unit
        // test explicit about preloading the corpus first.
        let _ = crate::opening::stats();
        let mut pos = Position::startpos();
        let mut moves = pos.generate_legal();
        let engine = Engine::new(12);
        engine.order_moves(&pos, &mut moves, None, 0);
        engine.prefer_root_book_moves(&pos, &mut moves, None);

        let first = moves[0].to_uci();
        assert!(
            crate::opening::book_moves(&pos)
                .iter()
                .any(|uci| uci == &first),
            "expected a book move first, got {first}"
        );
    }

    #[test]
    fn verified_candidate_must_respect_the_main_search_loss_budget() {
        assert!(within_loss_budget(42, 0, 50));
        assert!(!within_loss_budget(42, -20, 50));
        assert!(!within_loss_budget(20, -MATE + 3, 400));
    }

    #[test]
    fn terminal_variant_root_has_no_spurious_move() {
        let mut pos = Position::startpos();
        pos.variant = chess_core::Variant::ThreeCheck;
        pos.side = chess_core::Color::Black;
        pos.checks = [3, 0];
        pos.hash = pos.compute_hash();

        let info = Engine::new(12).search(
            &pos,
            SearchLimits {
                max_depth: 4,
                move_time_ms: None,
            },
            &|| false,
            |_| {},
        );
        assert!(info.best.is_none());
        assert_eq!(info.score_cp, -MATE);
    }
}

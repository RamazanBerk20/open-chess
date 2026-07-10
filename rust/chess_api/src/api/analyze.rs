//! Post-game move-by-move analysis: at each position it searches the best move
//! and the played move to the *same fixed depth*, classifies the played move
//! (book / brilliant / best / good / inaccuracy / miss / mistake / blunder) and
//! reports the evaluation (White POV) for an eval bar + graph. Streamed off the
//! UI thread; one update per ply plus a final `done` update with accuracies.
//!
//! Using a fixed depth (not a time budget) for both searches is what keeps
//! `cp_loss` consistent and non-negative: the played move's value comes from the
//! same horizon the best-move search already explored (and mostly from the
//! shared transposition table, so the second search is nearly free).

use std::sync::atomic::{AtomicBool, Ordering};

use chess_ai::{
    book_moves, lookup_opening, Engine, OpeningInfo, SearchInfo, SearchLimits, MATE, MATE_THRESHOLD,
};
use chess_core::{parse_fen, to_fen, Color, Move, Piece, Position, START_FEN};
use flutter_rust_bridge::frb;

use crate::frb_generated::StreamSink;

#[derive(Clone, Debug)]
pub struct AnalysisUpdate {
    pub ply: u32,
    pub uci: String,
    pub san: String,
    /// Evaluation after the move, White's point of view, clamped to ±10000.
    pub eval_cp: i32,
    /// 0 = not mate; otherwise signed plies-to-mate (White mating > 0).
    pub mate_in: i32,
    /// Evaluation of the position *before* the move (best play), White POV.
    /// Lets the eval bar/graph show a real value at the start ply.
    pub eval_before_cp: i32,
    /// Signed plies-to-mate for the position before the move (White mating > 0).
    pub mate_before_in: i32,
    pub best_uci: String,
    /// Engine's best move in SAN (for human-readable coach explanations).
    pub best_san: String,
    pub cp_loss: i32,
    pub classification: String,
    pub progress: u32,
    pub total: u32,
    pub done: bool,
    pub white_accuracy: f32,
    pub black_accuracy: f32,
    /// Populated only on the final update for canonical Standard games.
    pub opening: Option<AnalysisOpening>,
    /// Populated only on the final update for canonical Standard games.
    pub white_elo: Option<EloEstimate>,
    pub black_elo: Option<EloEstimate>,
}

/// Complete context for an analysis request.
///
/// FEN alone does not retain the selected game rules, so callers using a
/// saved/variant game must provide its [`GameVariant`](crate::api::game::GameVariant).
/// The legacy `analyze_game` bridge endpoint remains as a Standard wrapper for
/// existing callers.
#[derive(Clone, Debug)]
pub struct AnalyzeGameRequest {
    pub start_fen: String,
    pub moves: Vec<String>,
    pub depth: u32,
    pub variant: crate::api::game::GameVariant,
}

/// Named-opening details attached to a completed Standard-start analysis.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AnalysisOpening {
    pub eco: String,
    pub name: String,
    pub opening: String,
    pub gambit: Option<String>,
    pub variation: Option<String>,
}

impl From<OpeningInfo> for AnalysisOpening {
    fn from(value: OpeningInfo) -> Self {
        Self {
            eco: value.eco,
            name: value.name,
            opening: value.opening,
            gambit: value.gambit,
            variation: value.variation,
        }
    }
}

/// Confidence increases with the number of non-book moves used by an estimate.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum EloConfidence {
    Low,
    Medium,
    High,
}

/// A local, post-game Elo estimate based on non-book average centipawn loss.
#[derive(Clone, Debug, PartialEq)]
pub struct EloEstimate {
    pub elo: u32,
    pub confidence: EloConfidence,
    pub analyzed_moves: u32,
    pub average_cp_loss: f32,
}

/// Metadata computed at the end of analysis and attached to the final stream
/// update. It stays a separate internal value so normal per-move updates avoid
/// repeatedly cloning the same summary.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct AnalysisSummary {
    pub opening: Option<AnalysisOpening>,
    pub white_elo: Option<EloEstimate>,
    pub black_elo: Option<EloEstimate>,
}

/// Only one analysis runs at a time; this cancels it.
static CANCEL: AtomicBool = AtomicBool::new(false);

fn piece_val(p: Piece) -> i32 {
    match p {
        Piece::Pawn => 1,
        Piece::Knight | Piece::Bishop => 3,
        Piece::Rook => 5,
        Piece::Queen => 9,
        Piece::King => 0,
    }
}

fn material(pos: &Position, side: Color) -> i32 {
    let mut m = 0;
    for sq in 0..64u8 {
        if let Some((c, p)) = pos.piece_at(sq) {
            if c == side {
                m += piece_val(p);
            }
        }
    }
    m
}

/// White-POV centipawns from a side-to-move-POV score.
fn white_cp(score: i32, stm: Color) -> i32 {
    if stm == Color::White {
        score
    } else {
        -score
    }
}

/// White's win probability [0,1] from White-POV cp (logistic, Lichess constant).
fn win_prob(cp: i32) -> f64 {
    1.0 / (1.0 + (-0.00368208 * cp as f64).exp())
}

/// Win probability [0,1] for the side to move, from its own score.
fn win_stm(score: i32, stm: Color) -> f64 {
    let w = win_prob(white_cp(score, stm));
    if stm == Color::White {
        w
    } else {
        1.0 - w
    }
}

/// Signed plies-to-mate from a side-to-move score (positive = stm mates).
fn mate_in_from(score: i32) -> i32 {
    if score >= MATE_THRESHOLD {
        (MATE - score + 1) / 2
    } else if score <= -MATE_THRESHOLD {
        -((MATE + score + 1) / 2)
    } else {
        0
    }
}

/// Plies-to-mate signed to White's point of view (White mating > 0).
fn mate_white(score: i32, stm: Color) -> i32 {
    let mi = mate_in_from(score);
    if stm == Color::White {
        mi
    } else {
        -mi
    }
}

// Classification tuning (win-percent points lost, unless noted). Local + tunable.
const BEST_TOL: f64 = 1.0; // <= this many win% points lost still counts as "best"
/// A corpus move only earns the Book label when it remains close to the engine
/// choice. ECO data includes named traps and objectively losing gambits.
const BOOK_TOL: f64 = 3.0;
const MISS_TOL: f64 = 10.0;
const GOOD_TOL: f64 = 5.0;
const INACCURACY_TOL: f64 = 10.0;
const MISTAKE_TOL: f64 = 20.0;
const WINNING_WP: f64 = 0.80;
const SAC_MATERIAL: i32 = 3; // minor-piece-worth sacrifice to flag "brilliant"
/// A sacrifice only reads as "brilliant" when the side was NOT already winning
/// by more than this win-probability before the move. Past it the game is
/// effectively decided, so giving up material (even soundly) is just the "best"
/// move, not a brilliancy. 0.93 ≈ +700cp.
const BRILLIANT_MAX_BEFORE_WP: f64 = 0.93;

/// Classify the played move from win% loss, with sacrifice detection for
/// "brilliant" (mover materially down after the opponent's best reply yet still
/// winning) and a "miss" for a thrown-away winning chance.
#[allow(clippy::too_many_arguments)]
fn classify(
    stm: Color,
    mv: Move,
    best_mv: Option<Move>,
    best_score: i32,
    played_score: i32,
    wpl: f64, // win% points lost (>= 0)
    is_book: bool,
    before_mat: i32,
    child: &Position,         // position after the played move
    reply_best: Option<Move>, // opponent's best reply from the search
) -> &'static str {
    let best_wp = win_stm(best_score, stm);
    let played_wp = win_stm(played_score, stm);
    let winning_before = best_wp >= WINNING_WP || best_score >= MATE_THRESHOLD;
    let winning_after = played_wp >= WINNING_WP || played_score >= MATE_THRESHOLD;
    let played_is_best = best_mv == Some(mv) || wpl <= BEST_TOL;

    // Only corpus-backed moves that remain sound count as Book. The opening
    // corpus intentionally records named traps (including Fool's Mate), so
    // corpus membership must never suppress a real blunder classification.
    if is_book && wpl <= BOOK_TOL {
        return "book";
    }

    if played_is_best {
        // Brilliant: the best move is also a sound material sacrifice that stays
        // winning — but ONLY from a position that wasn't already won. When you
        // are already crushing (e.g. up a queen), a sound sac is just the best
        // move, not a brilliancy. Measure the mover's material after the
        // opponent's best reply (so a piece truly given up shows as a deficit).
        let already_winning_big =
            best_wp >= BRILLIANT_MAX_BEFORE_WP || best_score >= MATE_THRESHOLD;
        if winning_after && played_wp >= 0.5 && !already_winning_big {
            let mut after = child.clone();
            if let Some(rb) = reply_best {
                after.make_move(rb);
            }
            if material(&after, stm) <= before_mat - SAC_MATERIAL {
                return "brilliant";
            }
        }
        return "best";
    }

    // Miss: a winning chance thrown away (distinct from a plain mistake).
    if winning_before && !winning_after && wpl >= MISS_TOL {
        return "miss";
    }

    if wpl <= GOOD_TOL {
        "good"
    } else if wpl <= INACCURACY_TOL {
        "inaccuracy"
    } else if wpl <= MISTAKE_TOL {
        "mistake"
    } else {
        "blunder"
    }
}

/// Legacy Standard-chess bridge endpoint.
///
/// Keep this exact signature until checked-in FRB bindings are regenerated.
/// New callers should use [`analyze_game_request`] so variant games replay with
/// their actual rules.
pub fn analyze_game(
    start_fen: String,
    moves: Vec<String>,
    depth: u32,
    sink: StreamSink<AnalysisUpdate>,
) -> Result<(), String> {
    analyze_game_request(
        AnalyzeGameRequest {
            start_fen,
            moves,
            depth,
            variant: crate::api::game::GameVariant::Standard,
        },
        sink,
    )
}

/// Analyze a game with full start-position and variant context.
///
/// Streams an [`AnalysisUpdate`] per ply and attaches opening/Elo metadata to
/// the final update.
pub fn analyze_game_request(
    request: AnalyzeGameRequest,
    sink: StreamSink<AnalysisUpdate>,
) -> Result<(), String> {
    CANCEL.store(false, Ordering::Relaxed);
    let mut pos = parse_fen(&request.start_fen).map_err(|e| e.to_string())?;
    let standard_start = is_standard_start(&pos, request.variant);
    // FEN has no portable variant field. Apply the caller's actual rules and
    // rebuild its hash before engine use, just as the AI endpoint does.
    pos.variant = crate::api::game::to_variant(request.variant);
    pos.hash = pos.compute_hash();

    let total = request.moves.len() as u32;
    let depth = request.depth.clamp(1, 64) as u8;
    let mut eng = Engine::new(18);
    let cancel = || CANCEL.load(Ordering::Relaxed);

    // Best move searches `pos` to `depth`; the played move searches the child
    // one ply shallower so both look the same number of plies ahead of `pos`.
    let best_limits = SearchLimits {
        max_depth: depth,
        move_time_ms: None,
    };
    let child_limits = SearchLimits {
        max_depth: depth.saturating_sub(1).max(1),
        move_time_ms: None,
    };

    let mut acc_sum = [0.0f64; 2];
    let mut acc_cnt = [0u32; 2];
    let mut loss_sum = [0i64; 2];
    let mut loss_cnt = [0u32; 2];
    let mut opening = None;

    for (i, uci) in request.moves.iter().enumerate() {
        if cancel() {
            break;
        }
        let stm = pos.side;
        let mv = match pos.parse_uci(uci) {
            Ok(m) => m,
            Err(_) => break, // corrupt move list — stop cleanly
        };
        let san = pos.san_of(mv);
        let is_book = standard_start && book_moves(&pos).iter().any(|candidate| candidate == uci);

        // Best move + eval of the position before the move (stm POV).
        let best = eng.search(&pos, best_limits, &cancel, |_: &SearchInfo| {});
        let best_score = best.score_cp;
        let best_mv = best.best;
        let best_uci = best_mv.map(|m| m.to_uci()).unwrap_or_default();
        // SAN of the best move (computed before the played move is applied).
        let best_san = best_mv.map(|m| pos.san_of(m)).unwrap_or_default();

        // Play the move; search the child for the played value + opponent reply.
        // Mostly TT hits from the search above, so this is nearly free.
        let before_mat = material(&pos, stm);
        let mut child = pos.clone();
        child.make_move(mv);
        // If the move ended the game the child is terminal — `search` returns 0
        // for a no-legal-move root, which would mis-score a *checkmating* move as
        // a thrown-away win. Score terminal children directly instead.
        let (played_score, reply_best) = if child.variant_terminal().is_some() {
            // Three-check, King of the Hill, Atomic, and Fog can terminate with
            // legal moves still present. The mover created this terminal child.
            (MATE - 1, None)
        } else if child.generate_legal().is_empty() {
            if child.in_check(child.side) {
                (MATE - 1, None) // the move delivered checkmate → mover wins
            } else {
                (0, None) // stalemate → draw
            }
        } else {
            let reply = eng.search(&child, child_limits, &cancel, |_: &SearchInfo| {});
            (-reply.score_cp, reply.best) // back to stm's point of view
        };

        let cp_loss = (best_score - played_score).clamp(0, 10000);
        let eval_white = white_cp(played_score, stm).clamp(-10000, 10000);
        let mate_in = mate_white(played_score, stm);
        let eval_before = white_cp(best_score, stm).clamp(-10000, 10000);
        let mate_before = mate_white(best_score, stm);

        // Per-move accuracy + the win% loss that drives classification.
        let win_before = win_stm(best_score, stm);
        let win_after = win_stm(played_score, stm);
        let drop = ((win_before - win_after) * 100.0).max(0.0);
        let move_acc = (103.1668 * (-0.04354 * drop).exp() - 3.1669).clamp(0.0, 100.0);
        let side = if stm == Color::White { 0 } else { 1 };
        acc_sum[side] += move_acc;
        acc_cnt[side] += 1;

        let classification = classify(
            stm,
            mv,
            best_mv,
            best_score,
            played_score,
            drop,
            is_book,
            before_mat,
            &child,
            reply_best,
        );

        if standard_start && classification != "book" {
            loss_sum[side] += i64::from(cp_loss);
            loss_cnt[side] += 1;
        }
        pos.make_move(mv);
        if standard_start {
            if let Some(info) = lookup_opening(&pos) {
                opening = Some(info.into());
            }
        }

        if sink
            .add(AnalysisUpdate {
                ply: i as u32,
                uci: uci.clone(),
                san,
                eval_cp: eval_white,
                mate_in,
                eval_before_cp: eval_before,
                mate_before_in: mate_before,
                best_uci,
                best_san,
                cp_loss,
                classification: classification.to_string(),
                progress: i as u32 + 1,
                total,
                done: false,
                white_accuracy: 0.0,
                black_accuracy: 0.0,
                opening: None,
                white_elo: None,
                black_elo: None,
            })
            .is_err()
        {
            break; // listener dropped
        }
    }

    let avg = |s: f64, n: u32| if n > 0 { (s / n as f64) as f32 } else { 100.0 };
    let summary = AnalysisSummary {
        opening: standard_start.then_some(opening).flatten(),
        white_elo: standard_start
            .then(|| estimate_elo(loss_sum[0], loss_cnt[0]))
            .flatten(),
        black_elo: standard_start
            .then(|| estimate_elo(loss_sum[1], loss_cnt[1]))
            .flatten(),
    };
    let _ = sink.add(AnalysisUpdate {
        ply: 0,
        uci: String::new(),
        san: String::new(),
        eval_cp: 0,
        mate_in: 0,
        eval_before_cp: 0,
        mate_before_in: 0,
        best_uci: String::new(),
        best_san: String::new(),
        cp_loss: 0,
        classification: String::new(),
        progress: total,
        total,
        done: true,
        white_accuracy: avg(acc_sum[0], acc_cnt[0]),
        black_accuracy: avg(acc_sum[1], acc_cnt[1]),
        opening: summary.opening,
        white_elo: summary.white_elo,
        black_elo: summary.black_elo,
    });
    Ok(())
}

/// Convert a side's non-book average centipawn loss into a conservative local
/// Elo estimate. A short game cannot establish a rating: clean opening tactics
/// (such as Scholar's Mate) used to map to an implausibly high result because
/// the raw average could be zero after only a few moves. We therefore require
/// a useful sample and shrink it toward a broad club-player prior before using
/// the ACPL curve.
///
/// This remains a gameplay estimate, not an official rating or a replacement
/// for a rated-server calculation.
fn estimate_elo(loss_sum: i64, moves: u32) -> Option<EloEstimate> {
    const MIN_SAMPLE_MOVES: u32 = 8;
    const PRIOR_MOVES: f64 = 24.0;
    const PRIOR_ACPL: f64 = 180.0;

    if moves < MIN_SAMPLE_MOVES {
        return None;
    }

    let average_cp_loss = loss_sum as f64 / f64::from(moves);
    let adjusted_cp_loss =
        (loss_sum as f64 + PRIOR_MOVES * PRIOR_ACPL) / (f64::from(moves) + PRIOR_MOVES);
    let confidence = match moves {
        8..=19 => EloConfidence::Low,
        20..=39 => EloConfidence::Medium,
        _ => EloConfidence::High,
    };
    // Short samples must remain conservative even when every move was engine
    // perfect. The caps relax as the analysis has more original moves.
    let confidence_cap = match confidence {
        EloConfidence::Low => 1450.0,
        EloConfidence::Medium => 2100.0,
        EloConfidence::High => 2500.0,
    };
    let elo = (5480.0 - 850.0 * adjusted_cp_loss.max(10.0).ln())
        .clamp(400.0, confidence_cap)
        .round() as u32;
    Some(EloEstimate {
        elo,
        confidence,
        analyzed_moves: moves,
        average_cp_loss: average_cp_loss as f32,
    })
}

fn is_standard_start(position: &Position, variant: crate::api::game::GameVariant) -> bool {
    variant == crate::api::game::GameVariant::Standard && to_fen(position) == START_FEN
}

/// Cancel the running analysis.
#[frb(sync)]
pub fn analysis_cancel() {
    CANCEL.store(true, Ordering::Relaxed);
}

#[cfg(test)]
mod tests {
    use super::*;

    fn mv(uci: &str) -> Move {
        let mut p = Position::startpos();
        p.parse_uci(uci).unwrap()
    }

    // Classify a White move from synthetic best/played scores (stm POV).
    fn classify_white(
        is_book: bool,
        played: Move,
        best: Move,
        best_s: i32,
        played_s: i32,
    ) -> &'static str {
        let pos = Position::startpos();
        let child = pos.clone();
        let wpl =
            ((win_stm(best_s, Color::White) - win_stm(played_s, Color::White)) * 100.0).max(0.0);
        classify(
            Color::White,
            played,
            Some(best),
            best_s,
            played_s,
            wpl,
            is_book,
            material(&pos, Color::White),
            &child,
            None,
        )
    }

    #[test]
    fn classification_ladder() {
        let a = mv("e2e4");
        let b = mv("d2d4");
        // Played == best, non-winning → "best" (not "brilliant": no sacrifice).
        assert_eq!(classify_white(false, a, a, 30, 30), "best");
        // Corpus membership cannot hide a losing named trap.
        assert_eq!(classify_white(true, b, a, 0, -500), "blunder");
        assert_eq!(classify_white(true, a, a, 0, 0), "book");
        // Small win% loss → "good".
        assert_eq!(classify_white(false, b, a, 0, -33), "good");
        // Big win% loss from an equal position → "blunder".
        assert_eq!(classify_white(false, b, a, 0, -500), "blunder");
        // A winning position thrown away → "miss" (not a plain mistake/blunder).
        assert_eq!(classify_white(false, b, a, 400, 0), "miss");
        // Clearly winning best move stays "best".
        assert_eq!(classify_white(false, a, a, 600, 600), "best");
    }

    #[test]
    fn brilliant_requires_not_already_winning() {
        // "After the sac" the mover is a knight down: child = startpos minus the
        // b1 knight (material 36), before_mat = full startpos material (39).
        let before_mat = material(&Position::startpos(), Color::White);
        let child = parse_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/R1BQKBNR w KQkq - 0 1").unwrap();
        let m = mv("e2e4");
        // Winning but not yet decided (+600) → a sound sacrifice is "brilliant".
        assert_eq!(
            classify(
                Color::White,
                m,
                Some(m),
                600,
                600,
                0.0,
                false,
                before_mat,
                &child,
                None,
            ),
            "brilliant",
        );
        // Already crushing (+2500) → the same sacrifice is merely "best".
        assert_eq!(
            classify(
                Color::White,
                m,
                Some(m),
                2500,
                2500,
                0.0,
                false,
                before_mat,
                &child,
                None,
            ),
            "best",
        );
    }

    #[test]
    fn cp_loss_never_negative_and_eval_signs() {
        // best >= played by the search invariant, so cp_loss clamps to >= 0.
        assert_eq!((50_i32 - 200).clamp(0, 10000), 0);
        // White-POV eval flips for Black to move.
        assert_eq!(white_cp(120, Color::White), 120);
        assert_eq!(white_cp(120, Color::Black), -120);
        // Mate-distance signs to White's POV.
        assert!(mate_white(MATE - 3, Color::White) > 0);
        assert!(mate_white(MATE - 3, Color::Black) < 0);
    }

    #[test]
    fn elo_estimate_requires_a_real_sample_and_shrinks_short_games() {
        // A short, clean tactical game such as Scholar's Mate is not enough
        // evidence to call either player a master.
        assert!(estimate_elo(0, 0).is_none());
        assert!(estimate_elo(0, 7).is_none());

        let short_perfect = estimate_elo(0, 8).unwrap();
        assert_eq!(short_perfect.confidence, EloConfidence::Low);
        assert!(short_perfect.elo <= 1450);

        let expected = estimate_elo(1000, 10).unwrap(); // raw ACPL = 100
        assert_eq!(expected.confidence, EloConfidence::Low);
        assert_eq!(expected.average_cp_loss, 100.0);
        assert!(expected.elo < 1450);

        assert_eq!(
            estimate_elo(3000, 20).unwrap().confidence,
            EloConfidence::Medium
        );
        assert_eq!(
            estimate_elo(6000, 40).unwrap().confidence,
            EloConfidence::High
        );
        assert_eq!(estimate_elo(1_000_000, 8).unwrap().elo, 400);
    }

    #[test]
    fn only_canonical_standard_starts_receive_opening_or_elo_metadata() {
        let start = Position::startpos();
        assert!(is_standard_start(
            &start,
            crate::api::game::GameVariant::Standard
        ));
        assert!(!is_standard_start(
            &start,
            crate::api::game::GameVariant::Atomic
        ));
        let custom = parse_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 7 3").unwrap();
        assert!(!is_standard_start(
            &custom,
            crate::api::game::GameVariant::Standard
        ));
    }
}

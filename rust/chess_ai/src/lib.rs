//! `chess_ai` — hand-written search + evaluation.
//!
//! Negamax + alpha-beta with iterative deepening, quiescence, a Zobrist
//! transposition table, move ordering and a tapered (PeSTO) evaluation.
//! Pure: no bridge dependency. Cancellation is a caller-supplied
//! `Fn() -> bool`; time is read internally via `std::time::Instant`.

pub mod eval;
pub mod opening;
pub mod search;

pub use eval::{evaluate, MATE, MATE_THRESHOLD};
pub use opening::{
    book_moves, book_moves_if_ready, lookup as lookup_opening, lookup_line as lookup_opening_line,
    warm_up as warm_opening_book, OpeningInfo,
};
pub use search::{AiConfig, Engine, SearchInfo, SearchLimits};

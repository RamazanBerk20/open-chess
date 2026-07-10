//! Offline Standard-chess opening names and book moves.
//!
//! The embedded corpus is the Lichess `chess-openings` data set. It is parsed
//! once on first use with `chess_core`'s SAN parser, so the book always follows
//! the same legal-move rules as the engine. See `assets/openings/README.md` for
//! provenance and licensing.

use std::collections::{BTreeSet, HashMap};
use std::sync::{Once, OnceLock};

use chess_core::{Position, Variant};

const OPENING_VOLUMES: [&str; 5] = [
    include_str!("../assets/openings/a.tsv"),
    include_str!("../assets/openings/b.tsv"),
    include_str!("../assets/openings/c.tsv"),
    include_str!("../assets/openings/d.tsv"),
    include_str!("../assets/openings/e.tsv"),
];

/// A named opening position from the embedded Lichess ECO corpus.
///
/// `opening` is the opening family, `variation` is the text after `:` when
/// present, and `gambit` is the most specific named component containing
/// "Gambit". `ply` is the corpus line length and helps select a stable,
/// specific name when transpositions reach the same position.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct OpeningInfo {
    pub eco: String,
    pub name: String,
    pub opening: String,
    pub gambit: Option<String>,
    pub variation: Option<String>,
    pub ply: u32,
}

/// Size information for the embedded corpus. Useful for diagnostics and tests.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct OpeningBookStats {
    pub entries: usize,
    pub named_positions: usize,
    pub move_positions: usize,
}

#[derive(Default)]
struct OpeningBook {
    named_positions: HashMap<u64, OpeningInfo>,
    moves_by_position: HashMap<u64, Vec<String>>,
    entries: usize,
}

static BOOK: OnceLock<OpeningBook> = OnceLock::new();
static BOOK_WARMUP: Once = Once::new();

/// Return the named opening for this Standard-chess position, if it has one.
pub fn lookup(position: &Position) -> Option<OpeningInfo> {
    if position.variant != Variant::Standard {
        return None;
    }
    book().named_positions.get(&position.hash).cloned()
}

/// Return legal UCI moves recorded by the opening book for `position`.
///
/// The candidates are deterministic and deduplicated. The caller remains
/// responsible for choosing among them; book data has no game-frequency data.
pub fn book_moves(position: &Position) -> Vec<String> {
    if position.variant != Variant::Standard {
        return Vec::new();
    }
    book()
        .moves_by_position
        .get(&position.hash)
        .cloned()
        .unwrap_or_default()
}

/// Return book moves only when the corpus index is already available. Engine
/// searches use this deadline-safe form: parsing several thousand PGN lines on
/// a player's first move must never consume that move's search budget.
pub fn book_moves_if_ready(position: &Position) -> Vec<String> {
    if position.variant != Variant::Standard {
        return Vec::new();
    }
    BOOK.get()
        .and_then(|book| book.moves_by_position.get(&position.hash))
        .cloned()
        .unwrap_or_default()
}

/// Start the one-time opening-corpus parse on a background thread. It is safe
/// to call repeatedly and intentionally does not block a move search.
pub fn warm_up() {
    BOOK_WARMUP.call_once(|| {
        let _ = std::thread::Builder::new()
            .name("chess-opening-book".into())
            .spawn(|| {
                let _ = book();
            });
    });
}

/// Replay a UCI line and return the latest named position it reaches.
///
/// This intentionally keeps the last named position rather than requiring the
/// final game position to still be in the corpus. That follows the source
/// data's recommended "play backwards until a named position is found"
/// classification behavior.
pub fn lookup_line(start: &Position, moves: &[String]) -> Option<OpeningInfo> {
    if start.variant != Variant::Standard {
        return None;
    }

    let mut position = start.clone();
    let mut found = lookup(&position);
    for uci in moves {
        let Ok(mv) = position.parse_uci(uci) else {
            break;
        };
        position.make_move(mv);
        if let Some(info) = lookup(&position) {
            found = Some(info);
        }
    }
    found
}

/// Return the lazy index's current corpus statistics.
pub fn stats() -> OpeningBookStats {
    let book = book();
    OpeningBookStats {
        entries: book.entries,
        named_positions: book.named_positions.len(),
        move_positions: book.moves_by_position.len(),
    }
}

fn book() -> &'static OpeningBook {
    BOOK.get_or_init(|| build_book().expect("embedded Lichess opening corpus must parse"))
}

fn build_book() -> Result<OpeningBook, String> {
    let mut named_positions = HashMap::new();
    let mut candidate_moves: HashMap<u64, BTreeSet<String>> = HashMap::new();
    let mut entries = 0;

    for volume in OPENING_VOLUMES {
        for (line_index, line) in volume.lines().enumerate() {
            if line_index == 0 {
                continue; // `eco\tname\tpgn`
            }
            let (info, moves) = parse_entry(line).map_err(|err| {
                format!(
                    "opening corpus line {} could not be parsed: {err}",
                    line_index + 1
                )
            })?;
            let mut position = Position::startpos();

            for uci in &moves {
                candidate_moves
                    .entry(position.hash)
                    .or_default()
                    .insert(uci.clone());
                let mv = position.parse_uci(uci).map_err(|err| {
                    format!("generated UCI `{uci}` became illegal while indexing: {err}")
                })?;
                position.make_move(mv);
            }

            match named_positions.get(&position.hash) {
                Some(existing) if !is_more_specific(&info, existing) => {}
                _ => {
                    named_positions.insert(position.hash, info);
                }
            }
            entries += 1;
        }
    }

    Ok(OpeningBook {
        named_positions,
        moves_by_position: candidate_moves
            .into_iter()
            .map(|(hash, moves)| (hash, moves.into_iter().collect()))
            .collect(),
        entries,
    })
}

fn parse_entry(line: &str) -> Result<(OpeningInfo, Vec<String>), String> {
    let mut fields = line.splitn(3, '\t');
    let eco = fields
        .next()
        .filter(|value| !value.is_empty())
        .ok_or("missing ECO code")?;
    let name = fields
        .next()
        .filter(|value| !value.is_empty())
        .ok_or("missing opening name")?;
    let pgn = fields
        .next()
        .filter(|value| !value.is_empty())
        .ok_or("missing PGN")?;
    let moves = pgn_to_uci(pgn).map_err(|err| format!("{eco} {name}: {err}"))?;
    if moves.is_empty() {
        return Err(format!("{eco} {name}: no moves"));
    }

    let (opening, variation) = split_name(name);
    let gambit = gambit_name(&opening, variation.as_deref());
    Ok((
        OpeningInfo {
            eco: eco.to_owned(),
            name: name.to_owned(),
            opening,
            gambit,
            variation,
            ply: moves.len() as u32,
        },
        moves,
    ))
}

fn pgn_to_uci(pgn: &str) -> Result<Vec<String>, String> {
    let mut position = Position::startpos();
    let mut moves = Vec::new();

    for raw in pgn.split_whitespace() {
        let Some(san) = pgn_move_token(raw) else {
            continue;
        };
        let mv = position
            .parse_san(san)
            .map_err(|err| format!("invalid SAN `{san}`: {err}"))?;
        moves.push(mv.to_uci());
        position.make_move(mv);
    }
    Ok(moves)
}

/// Remove an optional compact PGN move number (`1.e4`, `1...e5`) and ignore
/// results/NAGs. The supplied Lichess corpus has no comments or variations.
fn pgn_move_token(raw: &str) -> Option<&str> {
    if raw.starts_with('$') || matches!(raw, "1-0" | "0-1" | "1/2-1/2" | "*") {
        return None;
    }

    let trimmed = raw.trim_start_matches(|ch: char| ch.is_ascii_digit() || ch == '.');
    if trimmed.is_empty() || matches!(trimmed, "1-0" | "0-1" | "1/2-1/2" | "*") {
        None
    } else {
        Some(trimmed)
    }
}

fn split_name(name: &str) -> (String, Option<String>) {
    match name.split_once(':') {
        Some((opening, variation)) => (
            opening.trim().to_owned(),
            (!variation.trim().is_empty()).then(|| variation.trim().to_owned()),
        ),
        None => (name.trim().to_owned(), None),
    }
}

fn gambit_name(opening: &str, variation: Option<&str>) -> Option<String> {
    if opening.to_ascii_lowercase().contains("gambit") {
        return Some(opening.to_owned());
    }

    variation.and_then(|value| {
        value
            .split(',')
            .map(str::trim)
            .find(|part| part.to_ascii_lowercase().contains("gambit"))
            .map(ToOwned::to_owned)
    })
}

fn is_more_specific(candidate: &OpeningInfo, current: &OpeningInfo) -> bool {
    candidate.ply > current.ply
        || (candidate.ply == current.ply
            && (candidate.name.len() > current.name.len()
                || (candidate.name.len() == current.name.len() && candidate.name < current.name)))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn position_after(moves: &[&str]) -> Position {
        let mut position = Position::startpos();
        for uci in moves {
            let mv = position.parse_uci(uci).unwrap();
            position.make_move(mv);
        }
        position
    }

    #[test]
    fn corpus_is_complete_and_indexed() {
        let stats = stats();
        assert_eq!(stats.entries, 3790);
        assert!(stats.named_positions > 3_000);
        assert!(stats.move_positions > 3_000);
    }

    #[test]
    fn common_start_moves_are_book_candidates() {
        let moves = book_moves(&Position::startpos());
        for uci in ["e2e4", "d2d4", "c2c4", "g1f3"] {
            assert!(
                moves.iter().any(|candidate| candidate == uci),
                "missing {uci}"
            );
        }
    }

    #[test]
    fn line_lookup_returns_a_named_opening_and_gambit_parts() {
        let moves: Vec<String> = ["e2e4", "e7e5", "f2f4"]
            .into_iter()
            .map(str::to_owned)
            .collect();
        let info = lookup_line(&Position::startpos(), &moves).unwrap();
        assert!(info.name.contains("King's Gambit"));
        assert_eq!(info.gambit.as_deref(), Some("King's Gambit"));
        assert_eq!(info.variation, None);
    }

    #[test]
    fn lookup_is_standard_only() {
        let mut position = position_after(&["e2e4"]);
        assert!(lookup(&position).is_some());
        position.variant = Variant::Atomic;
        assert!(lookup(&position).is_none());
        assert!(book_moves(&position).is_empty());
    }

    #[test]
    fn pgn_tokens_support_compact_move_numbers() {
        assert_eq!(pgn_move_token("1.e4"), Some("e4"));
        assert_eq!(pgn_move_token("1...e5"), Some("e5"));
        assert_eq!(pgn_move_token("2."), None);
        assert_eq!(pgn_move_token("1-0"), None);
    }
}

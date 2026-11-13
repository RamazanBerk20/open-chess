//! Off-UI-thread AI search exposed to Flutter as a stream, with cancellation.
//!
//! `ai_search` takes a [`StreamSink`], so flutter_rust_bridge runs it on a Rust
//! worker thread (never the Dart UI isolate) and surfaces it as a Dart `Stream`.
//! It emits one [`AiUpdate`] per completed search depth plus a final `done`
//! update. `ai_cancel(id)` flips a shared flag the search polls.

use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};

use chess_ai::{warm_opening_book, AiConfig, Engine, SearchInfo};
use chess_core::{parse_fen_variant, VariantExtras};
use flutter_rust_bridge::frb;

use crate::frb_generated::StreamSink;

/// One progress update from the search.
#[derive(Clone, Debug)]
pub struct AiUpdate {
    pub depth: u32,
    pub score_cp: i32,
    pub best_uci: String,
    pub pv: Vec<String>,
    pub nodes: u64,
    pub done: bool,
}

/// Difficulty configuration passed from Dart.
#[derive(Clone, Copy, Debug)]
pub struct AiConfigDto {
    pub max_depth: u32,
    pub move_time_ms: Option<u64>,
    pub max_eval_loss_cp: i32,
    pub random_move_chance: f32,
    pub candidate_depth: u32,
    pub contempt: i32,
    pub seed: u64,
}

/// Complete AI-search input. Grouping the board state makes the bridge stable
/// as variants gain more state and avoids an error-prone positional argument
/// list on the Dart boundary.
#[derive(Clone, Debug)]
pub struct AiSearchRequest {
    pub search_id: u64,
    pub fen: String,
    pub config: AiConfigDto,
    pub history: Vec<u64>,
    pub variant: crate::api::game::GameVariant,
    pub white_checks: u32,
    pub black_checks: u32,
    pub white_hand: Vec<u32>,
    pub black_hand: Vec<u32>,
    pub promoted: u64,
}

/// Lifecycle of one search id. A cancel that arrives before the worker has
/// registered leaves a short-lived `Cancelled` tombstone, so the search that
/// registers afterwards stops immediately instead of running to its deadline.
enum SearchSlot {
    /// Registered and searching; `token` tells two searches with one id apart.
    Searching { token: u64, flag: Arc<AtomicBool> },
    /// Cancelled before registration (expires: Dart may reuse ids later).
    Cancelled { at: Instant },
}

/// A tombstone only has to bridge the FRB dispatch delay.
const TOMBSTONE_TTL: Duration = Duration::from_secs(5);

type Registry = HashMap<u64, SearchSlot>;

fn registry() -> &'static Mutex<Registry> {
    static R: OnceLock<Mutex<Registry>> = OnceLock::new();
    R.get_or_init(|| Mutex::new(HashMap::new()))
}

/// Lock the registry, recovering from a poisoned mutex (a prior search panic)
/// instead of cascading the panic — the map itself is always in a valid state.
fn reg() -> std::sync::MutexGuard<'static, Registry> {
    registry().lock().unwrap_or_else(|e| e.into_inner())
}

fn prune_tombstones(map: &mut Registry) {
    map.retain(|_, slot| match slot {
        SearchSlot::Cancelled { at } => at.elapsed() < TOMBSTONE_TTL,
        SearchSlot::Searching { .. } => true,
    });
}

/// Register a search. Returns `None` when a fresh cancel tombstone was waiting.
fn register(id: u64) -> Option<(u64, Arc<AtomicBool>)> {
    static NEXT_TOKEN: AtomicU64 = AtomicU64::new(1);
    let mut map = reg();
    prune_tombstones(&mut map);
    if matches!(map.get(&id), Some(SearchSlot::Cancelled { .. })) {
        map.remove(&id);
        return None;
    }
    let token = NEXT_TOKEN.fetch_add(1, Ordering::Relaxed);
    let flag = Arc::new(AtomicBool::new(false));
    // A duplicate id replaces the older search's slot; the older guard then
    // leaves this one alone because the token differs.
    if let Some(SearchSlot::Searching { flag: old, .. }) = map.insert(
        id,
        SearchSlot::Searching {
            token,
            flag: flag.clone(),
        },
    ) {
        old.store(true, Ordering::Relaxed);
    }
    Some((token, flag))
}

/// Removes a search's slot on drop (normal return, `?`, or a panic), but only
/// while the slot still belongs to this search.
struct RegistryGuard {
    id: u64,
    token: u64,
}

impl Drop for RegistryGuard {
    fn drop(&mut self) {
        let mut map = reg();
        if matches!(map.get(&self.id), Some(SearchSlot::Searching { token, .. }) if *token == self.token)
        {
            map.remove(&self.id);
        }
    }
}

/// One engine (and its transposition table) is reused across searches of the
/// same variant and size instead of allocating up to 48 MB per move. A search
/// running concurrently with another simply builds its own.
type CachedEngine = (u32, chess_core::Variant, Engine);

fn engine_cache() -> &'static Mutex<Option<CachedEngine>> {
    static E: OnceLock<Mutex<Option<CachedEngine>>> = OnceLock::new();
    E.get_or_init(|| Mutex::new(None))
}

fn take_engine(bits: u32, variant: chess_core::Variant) -> Engine {
    let cached = engine_cache()
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .take();
    match cached {
        // Hashes do not encode the variant, so a table is only reused within one.
        Some((b, v, eng)) if b == bits && v == variant => eng,
        _ => Engine::new(bits),
    }
}

fn return_engine(bits: u32, variant: chess_core::Variant, eng: Engine) {
    *engine_cache().lock().unwrap_or_else(|e| e.into_inner()) = Some((bits, variant, eng));
}

fn done_update(info: &SearchInfo) -> AiUpdate {
    AiUpdate {
        depth: info.depth as u32,
        score_cp: info.score_cp,
        best_uci: info.best.map(|m| m.to_uci()).unwrap_or_default(),
        pv: info.pv.iter().map(|m| m.to_uci()).collect(),
        nodes: info.nodes,
        done: true,
    }
}

/// Run a search for `fen`, streaming progress. `search_id` identifies it for
/// cancellation. Runs off the UI thread (StreamSink param).
pub fn ai_search(request: AiSearchRequest, sink: StreamSink<AiUpdate>) -> Result<(), String> {
    // The full corpus parses in a background thread. Search-side lookup skips
    // it until ready, keeping a first AI move inside its configured deadline.
    warm_opening_book();
    // The FEN carries no variant/reserve info; restore it so the engine plays by
    // the variant's rules (three-check counts, Crazyhouse hand + promoted mask).
    let mut hand = [[0u8; 5]; 2];
    if request.white_hand.len() == 5 && request.black_hand.len() == 5 {
        for (side, counts) in [&request.white_hand, &request.black_hand]
            .into_iter()
            .enumerate()
        {
            for (slot, &count) in hand[side].iter_mut().zip(counts) {
                *slot = u8::try_from(count).map_err(|_| "reserve count out of range")?;
            }
        }
    }
    let extras = VariantExtras {
        checks: [
            u8::try_from(request.white_checks).map_err(|_| "check counter out of range")?,
            u8::try_from(request.black_checks).map_err(|_| "check counter out of range")?,
        ],
        hand,
        promoted: request.promoted,
    };
    let pos = parse_fen_variant(
        &request.fen,
        crate::api::game::to_variant(request.variant),
        &extras,
    )
    .map_err(|e| e.to_string())?;

    let Some((token, flag)) = register(request.search_id) else {
        // Cancelled before it started: finish the stream without searching.
        let _ = sink.add(done_update(&SearchInfo::default()));
        return Ok(());
    };
    let _guard = RegistryGuard {
        id: request.search_id,
        token,
    };

    let bits = if request.config.max_depth >= 11 {
        21
    } else {
        19
    };
    let mut eng = take_engine(bits, pos.variant);
    eng.set_game_history(&request.history);
    // Fog of War searches pseudo-legal moves (no king-safety filter), so the
    // branching factor is much larger — cap depth/time so moves stay snappy.
    let is_fog = pos.variant == chess_core::Variant::FogOfWar;
    let cfg = AiConfig {
        max_depth: {
            let d = request.config.max_depth.clamp(1, 255) as u8;
            if is_fog {
                d.min(4)
            } else {
                d
            }
        },
        move_time_ms: if is_fog {
            Some(request.config.move_time_ms.unwrap_or(800).min(500))
        } else {
            request.config.move_time_ms
        },
        max_eval_loss_cp: request.config.max_eval_loss_cp.max(0),
        random_move_chance: request.config.random_move_chance.clamp(0.0, 1.0),
        candidate_depth: request.config.candidate_depth.clamp(1, 255) as u8,
        contempt: request.config.contempt,
        seed: request.config.seed,
    };

    let cancel_flag = flag.clone();
    let cancel = move || cancel_flag.load(Ordering::Relaxed);

    let stop_flag = flag.clone();
    let on_info = |info: &SearchInfo| {
        let update = AiUpdate {
            depth: info.depth as u32,
            score_cp: info.score_cp,
            best_uci: info.best.map(|m| m.to_uci()).unwrap_or_default(),
            pv: info.pv.iter().map(|m| m.to_uci()).collect(),
            nodes: info.nodes,
            done: false,
        };
        // If the Dart listener was dropped, stop searching.
        if sink.add(update).is_err() {
            stop_flag.store(true, Ordering::Relaxed);
        }
    };

    let result = eng.search_with_config(&pos, cfg, &cancel, on_info);
    return_engine(bits, pos.variant, eng);

    let _ = sink.add(done_update(&result));

    Ok(())
}

/// Request cancellation of the search with `search_id`.
#[frb(sync)]
pub fn ai_cancel(search_id: u64) {
    let mut map = reg();
    prune_tombstones(&mut map);
    match map.get(&search_id) {
        Some(SearchSlot::Searching { flag, .. }) => flag.store(true, Ordering::Relaxed),
        // Not registered yet (or already finished): leave a tombstone.
        _ => {
            map.insert(search_id, SearchSlot::Cancelled { at: Instant::now() });
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cancel_before_register_is_not_lost() {
        let id = u64::MAX - 7;
        ai_cancel(id);
        assert!(register(id).is_none());
        // The tombstone is consumed: a later search with the id runs.
        let (token, _) = register(id).unwrap();
        drop(RegistryGuard { id, token });
        assert!(reg().get(&id).is_none());
    }

    #[test]
    fn duplicate_ids_do_not_clobber_each_other() {
        let id = u64::MAX - 8;
        let (first, first_flag) = register(id).unwrap();
        let (second, second_flag) = register(id).unwrap();
        assert!(
            first_flag.load(Ordering::Relaxed),
            "older search is stopped"
        );
        drop(RegistryGuard { id, token: first });
        ai_cancel(id);
        assert!(second_flag.load(Ordering::Relaxed), "newer slot survived");
        drop(RegistryGuard { id, token: second });
    }
}

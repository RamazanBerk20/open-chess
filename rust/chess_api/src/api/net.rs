//! LAN multiplayer bridge: mDNS discovery + a TCP/JSON session.
//!
//! Networking runs on a shared tokio runtime. `net_host`/`net_join` return a
//! `Stream<NetEvent>` (run off the UI thread); the `net_send_*` commands push
//! protocol messages to the active connection. Every incoming move is validated
//! against a local `chess_core` game; illegal/out-of-turn moves are rejected.

use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

use chess_core::{Color, Game, GameStatus, Piece, Variant};
use chess_net::{
    HostAdvertisement, Message, PlayerProfile as ProtocolProfile, SessionRole, VariantState,
    MAX_AVATAR_BYTES, MAX_MESSAGE_BYTES, PROTOCOL_VERSION,
};
use flutter_rust_bridge::frb;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::tcp::OwnedWriteHalf;
use tokio::net::{TcpListener, TcpStream};
use tokio::runtime::Runtime;
use tokio::sync::mpsc::{UnboundedReceiver, UnboundedSender};

use crate::frb_generated::StreamSink;

type NetReader = BufReader<tokio::net::tcp::OwnedReadHalf>;

const MAX_CHAT_BYTES: usize = 2 * 1024;
/// Stable host ports let users permit LAN play without opening every ephemeral
/// TCP port in a local firewall. Multiple local hosts use the next free port.
const LAN_PORT_MIN: u16 = 1714;
const LAN_PORT_MAX: u16 = 1764;
/// Handshakes are read in background tasks so a peer that connects but never
/// sends `Hello` cannot pause the authoritative host loop. Keep that work
/// bounded so a connection flood cannot turn into unbounded pending tasks.
const MAX_PENDING_HOST_HANDSHAKES: usize = 32;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum NetEventKind {
    Connected,
    Move,
    Resign,
    DrawOffer,
    DrawResponse,
    Chat,
    /// Private spectator-only chat. Player transports never surface this event.
    SpectatorChat,
    Disconnected,
    Error,
    /// A spectator joined an enabled live host. This is informational for the
    /// host UI; the spectator itself receives its game-start event.
    SpectatorJoined,
    // Bughouse (host-authoritative star).
    BugJoin,   // a player joined the host's lobby
    BugStart,  // seats assigned, match begins
    BugMove,   // a move/drop on a board
    BugPass,   // a captured piece fed to a partner's reserve
    BugResult, // the match ended
    // 4-player chess (host-authoritative star).
    FourJoin,
    FourStart,
    FourMove,
    FourResult,
}

/// A flattened event (no payload enum, so no `freezed` needed on Dart).
#[derive(Clone, Debug)]
pub struct NetEvent {
    pub kind: NetEventKind,
    pub you_are_white: bool,
    pub white_name: String,
    pub black_name: String,
    pub base_minutes: u32,
    pub increment_seconds: u32,
    pub fen: String,
    pub uci: String,
    pub white_ms: i64,
    pub black_ms: i64,
    pub draw_accepted: bool,
    pub text: String,
    /// Authenticated sender for spectator-only chat messages.
    pub sender: String,
    /// Variant code agreed for this game (e.g. "standard", "crazyhouse").
    pub variant: String,
    /// True only for a read-only live spectator session.
    pub is_spectator: bool,
    /// Both player profiles are carried in every initial connection event.
    pub white_profile: PlayerProfileWire,
    pub black_profile: PlayerProfileWire,
    /// Profile associated with a lobby join / spectator join event.
    pub peer_profile: PlayerProfileWire,
    /// Variant state excluded from FEN, used to restore a live spectator.
    pub white_checks: u32,
    pub black_checks: u32,
    pub white_hand: Vec<u32>,
    pub black_hand: Vec<u32>,
    pub promoted: u64,
    // ---- Bughouse fields ----
    pub board: u32,                            // 0=A, 1=B
    pub to_board: u32,                         // BugPass target board
    pub to_color: u32,                         // BugPass target colour (0=white, 1=black)
    pub piece: u32,                            // BugPass piece (0=Pawn..4=Queen)
    pub seat: u32,                             // a seat index (0..3)
    pub winning_team: u32,                     // BugResult (1 or 2)
    pub your_seats: Vec<u32>,                  // seats this client controls (BugStart)
    pub seats: Vec<String>,                    // the four player names (BugStart)
    pub seat_profiles: Vec<PlayerProfileWire>, // full four-player seat profiles
}

impl NetEvent {
    fn of(kind: NetEventKind) -> NetEvent {
        NetEvent {
            kind,
            you_are_white: false,
            white_name: String::new(),
            black_name: String::new(),
            base_minutes: 0,
            increment_seconds: 0,
            fen: String::new(),
            uci: String::new(),
            white_ms: 0,
            black_ms: 0,
            draw_accepted: false,
            text: String::new(),
            sender: String::new(),
            variant: String::new(),
            is_spectator: false,
            white_profile: PlayerProfileWire::empty(),
            black_profile: PlayerProfileWire::empty(),
            peer_profile: PlayerProfileWire::empty(),
            white_checks: 0,
            black_checks: 0,
            white_hand: Vec::new(),
            black_hand: Vec::new(),
            promoted: 0,
            board: 0,
            to_board: 0,
            to_color: 0,
            piece: 0,
            seat: 0,
            winning_team: 0,
            your_seats: Vec::new(),
            seats: Vec::new(),
            seat_profiles: Vec::new(),
        }
    }
}

/// Bridge-safe profile. Protocol serialization uses Base64 internally; Flutter
/// receives compact bytes and can render the built-in pawn for an empty avatar.
#[derive(Clone, Debug)]
pub struct PlayerProfileWire {
    pub username: String,
    pub avatar_bytes: Vec<u8>,
}

impl PlayerProfileWire {
    fn empty() -> Self {
        Self {
            username: String::new(),
            avatar_bytes: Vec::new(),
        }
    }

    fn to_protocol(&self) -> Result<ProtocolProfile, String> {
        if self.avatar_bytes.len() > MAX_AVATAR_BYTES {
            return Err(format!("avatar exceeds {MAX_AVATAR_BYTES} byte LAN limit"));
        }
        ProtocolProfile::from_avatar_bytes(self.username.clone(), &self.avatar_bytes)
    }

    fn from_protocol(profile: &ProtocolProfile) -> Result<Self, String> {
        Ok(Self {
            username: profile.username.clone(),
            avatar_bytes: profile.avatar_bytes()?,
        })
    }
}

/// Wire code → variant (the stable string sent in the Start message).
fn variant_from_code(s: &str) -> Variant {
    match s {
        "three_check" => Variant::ThreeCheck,
        "king_of_the_hill" => Variant::KingOfTheHill,
        "chess960" => Variant::Chess960,
        "atomic" => Variant::Atomic,
        "crazyhouse" => Variant::Crazyhouse,
        "bughouse" => Variant::Bughouse,
        "fog_of_war" => Variant::FogOfWar,
        _ => Variant::Standard,
    }
}

/// Build the move-validation game for `fen` with `variant` applied (the FEN may
/// be a Chess960 X-FEN that already carries it; setting it again is harmless).
fn variant_game(fen: &str, variant: Variant, variant_state: &VariantState) -> Result<Game, String> {
    variant_state.validate()?;
    let mut pos = chess_core::parse_fen(fen).map_err(|e| e.to_string())?;
    pos.variant = variant;
    pos.checks = [variant_state.white_checks, variant_state.black_checks];
    pos.hand = [variant_state.white_hand, variant_state.black_hand];
    pos.promoted = variant_state.promoted;
    pos.hash = pos.compute_hash();
    Ok(Game::from_position(pos))
}

/// A host discovered on the LAN.
#[derive(Clone, Debug)]
pub struct NetHost {
    pub name: String,
    /// Internal connection target. The app deliberately does not render this.
    pub addr: String,
    pub time_control: String,
    pub mode: String,
    pub variant: String,
    pub spectators_enabled: bool,
    pub player_count: u32,
    pub max_players: u32,
}

fn runtime() -> &'static Runtime {
    static RT: OnceLock<Runtime> = OnceLock::new();
    RT.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .expect("tokio runtime")
    })
}

/// Outgoing-command sender for the active session, tagged with a generation so
/// a finishing session only clears the slot if it still owns it (a newer
/// session won't be wiped by an older one's cleanup).
/// Lock a mutex, recovering from poisoning (a prior holder panicked) instead of
/// cascading the panic. The data these mutexes protect — channel slots and seat
/// assignments — is always left in a consistent state, so recovery is safe.
fn lock<T>(m: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    m.lock().unwrap_or_else(|e| e.into_inner())
}

/// The bool prevents a spectator-side bridge command from ever entering the
/// transport, even before the host performs its own role check.
type CmdSlot = Mutex<Option<(u64, UnboundedSender<Message>, bool)>>;

fn cmd_slot() -> &'static CmdSlot {
    static C: OnceLock<CmdSlot> = OnceLock::new();
    C.get_or_init(|| Mutex::new(None))
}

static SESSION_GEN: AtomicU64 = AtomicU64::new(0);
/// Durable cancellation epoch. `Notify::notify_waiters` is only a wake-up hint;
/// this token makes a leave/new-session request observable even when it races a
/// task before that task has started waiting on the notification.
static SESSION_EPOCH: AtomicU64 = AtomicU64::new(0);

/// Signals a waiting host (parked at accept) or a prior session to stop, so a
/// new session / leave doesn't leak the old listener + mDNS advertisement.
fn session_cancel() -> &'static tokio::sync::Notify {
    static N: OnceLock<tokio::sync::Notify> = OnceLock::new();
    N.get_or_init(tokio::sync::Notify::new)
}

fn begin_session() -> u64 {
    let epoch = SESSION_EPOCH.fetch_add(1, Ordering::Relaxed) + 1;
    session_cancel().notify_waiters();
    epoch
}

fn cancel_sessions() {
    SESSION_EPOCH.fetch_add(1, Ordering::Relaxed);
    session_cancel().notify_waiters();
}

fn session_current(epoch: u64) -> bool {
    SESSION_EPOCH.load(Ordering::Relaxed) == epoch
}

/// Connect without leaving a cancelled lobby screen stuck behind the operating
/// system's TCP timeout. The durable epoch check covers a cancellation that
/// races `Notify::notified` before this task begins waiting.
async fn join_connect(addr: &str, session_epoch: u64) -> Result<Option<TcpStream>, String> {
    let connect = TcpStream::connect(addr);
    tokio::pin!(connect);
    let timeout = tokio::time::sleep(Duration::from_secs(8));
    tokio::pin!(timeout);
    let mut cancel_poll = tokio::time::interval(Duration::from_millis(100));
    cancel_poll.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    loop {
        if !session_current(session_epoch) {
            return Ok(None);
        }
        tokio::select! {
            result = &mut connect => {
                if !session_current(session_epoch) {
                    return Ok(None);
                }
                return result.map(Some).map_err(es);
            }
            _ = &mut timeout => {
                if !session_current(session_epoch) {
                    return Ok(None);
                }
                return Err("LAN connection timed out".into());
            }
            _ = cancel_poll.tick() => {}
            _ = session_cancel().notified() => {}
        }
    }
}

/// Send the initial client message with the same cancellation behavior as the
/// connect and handshake stages. `false` means the joining session went stale.
async fn join_write(
    writer: &mut OwnedWriteHalf,
    message: Message,
    session_epoch: u64,
) -> Result<bool, String> {
    let encoded = message.encode();
    let write = writer.write_all(encoded.as_bytes());
    tokio::pin!(write);
    let timeout = tokio::time::sleep(Duration::from_secs(5));
    tokio::pin!(timeout);
    let mut cancel_poll = tokio::time::interval(Duration::from_millis(100));
    cancel_poll.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    loop {
        if !session_current(session_epoch) {
            return Ok(false);
        }
        tokio::select! {
            result = &mut write => {
                if !session_current(session_epoch) {
                    return Ok(false);
                }
                return result.map(|()| true).map_err(es);
            }
            _ = &mut timeout => {
                if !session_current(session_epoch) {
                    return Ok(false);
                }
                return Err("LAN handshake write timed out".into());
            }
            _ = cancel_poll.tick() => {}
            _ = session_cancel().notified() => {}
        }
    }
}

/// Read the host's initial response with a bounded timeout and prompt session
/// cancellation. Subsequent live-session reads already run in cancellation
/// aware `select!` loops.
async fn join_handshake(
    reader: &mut NetReader,
    session_epoch: u64,
) -> Result<Option<Message>, String> {
    let read = read_handshake_message(reader);
    tokio::pin!(read);
    let timeout = tokio::time::sleep(Duration::from_secs(5));
    tokio::pin!(timeout);
    let mut cancel_poll = tokio::time::interval(Duration::from_millis(100));
    cancel_poll.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    loop {
        if !session_current(session_epoch) {
            return Ok(None);
        }
        tokio::select! {
            result = &mut read => {
                if !session_current(session_epoch) {
                    return Ok(None);
                }
                return result.map(Some);
            }
            _ = &mut timeout => {
                if !session_current(session_epoch) {
                    return Ok(None);
                }
                return Err("LAN handshake timed out".into());
            }
            _ = cancel_poll.tick() => {}
            _ = session_cancel().notified() => {}
        }
    }
}

static BROWSE_STOP: AtomicBool = AtomicBool::new(false);

// ---- Discovery ----------------------------------------------------------

/// Browse for LAN hosts. Streams each resolved host until `net_stop_browse`.
pub fn net_browse(sink: StreamSink<NetHost>) -> Result<(), String> {
    BROWSE_STOP.store(false, Ordering::Relaxed);
    let (browser, rx) = chess_net::browse().map_err(|e| e.to_string())?;
    loop {
        if BROWSE_STOP.load(Ordering::Relaxed) {
            break;
        }
        match rx.recv_timeout(Duration::from_millis(400)) {
            Ok(h) => {
                let ok = sink
                    .add(NetHost {
                        name: h.name,
                        addr: h.addr,
                        time_control: h.time_control,
                        mode: h.mode,
                        variant: h.variant,
                        spectators_enabled: h.spectators_enabled,
                        player_count: h.player_count,
                        max_players: h.max_players,
                    })
                    .is_ok();
                if !ok {
                    break;
                }
            }
            Err(std::sync::mpsc::RecvTimeoutError::Timeout) => continue,
            Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => break,
        }
    }
    drop(browser);
    Ok(())
}

#[frb(sync)]
pub fn net_stop_browse() {
    BROWSE_STOP.store(true, Ordering::Relaxed);
}

// ---- Session ------------------------------------------------------------

/// Host a two-player game. Once a player has joined, enabled hosts can accept
/// any number of read-only spectators and fan out the authoritative position
/// stream to them.
#[allow(clippy::too_many_arguments)]
pub fn net_host(
    profile: PlayerProfileWire,
    base_minutes: u32,
    increment_seconds: u32,
    host_white: bool,
    variant: String,
    chess960_index: u32,
    allow_spectators: bool,
    sink: StreamSink<NetEvent>,
) -> Result<(), String> {
    let epoch = begin_session();
    runtime().block_on(async move {
        if let Err(e) = host_task(
            profile,
            base_minutes,
            increment_seconds,
            host_white,
            variant,
            chess960_index,
            allow_spectators,
            &sink,
            epoch,
        )
        .await
        {
            let mut ev = NetEvent::of(NetEventKind::Error);
            ev.text = e;
            let _ = sink.add(ev);
        }
        let _ = sink.add(NetEvent::of(NetEventKind::Disconnected));
    });
    Ok(())
}

/// Join a two-player host as the playing opponent.
pub fn net_join(
    addr: String,
    profile: PlayerProfileWire,
    sink: StreamSink<NetEvent>,
) -> Result<(), String> {
    let epoch = begin_session();
    runtime().block_on(async move {
        if let Err(e) = join_task(addr, profile, SessionRole::Player, &sink, epoch).await {
            if session_current(epoch) {
                let mut ev = NetEvent::of(NetEventKind::Error);
                ev.text = e;
                let _ = sink.add(ev);
            }
        }
        if session_current(epoch) {
            let _ = sink.add(NetEvent::of(NetEventKind::Disconnected));
        }
    });
    Ok(())
}

/// Join an enabled live two-player host as a strictly read-only spectator.
pub fn net_spectate(
    addr: String,
    profile: PlayerProfileWire,
    sink: StreamSink<NetEvent>,
) -> Result<(), String> {
    let epoch = begin_session();
    runtime().block_on(async move {
        if let Err(e) = join_task(addr, profile, SessionRole::Spectator, &sink, epoch).await {
            if session_current(epoch) {
                let mut ev = NetEvent::of(NetEventKind::Error);
                ev.text = e;
                let _ = sink.add(ev);
            }
        }
        if session_current(epoch) {
            let _ = sink.add(NetEvent::of(NetEventKind::Disconnected));
        }
    });
    Ok(())
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum HostSource {
    Player,
    Spectator(u64),
}

struct HostPeer {
    id: u64,
    tx: UnboundedSender<Message>,
    username: String,
}

enum HostInbound {
    Message(HostSource, Message),
    Closed(HostSource),
}

/// A validated socket handed back to the host authority loop. The loop alone
/// decides whether the requested role is currently allowed; the background
/// task only performs bounded protocol/profile validation.
enum HostHandshake {
    Ready {
        profile: ProtocolProfile,
        role: SessionRole,
        reader: NetReader,
        writer: OwnedWriteHalf,
    },
    Finished,
}

async fn host_writer(mut wr: OwnedWriteHalf, mut rx: UnboundedReceiver<Message>) {
    while let Some(message) = rx.recv().await {
        if wr.write_all(message.encode().as_bytes()).await.is_err() {
            break;
        }
    }
}

async fn host_reader(source: HostSource, mut reader: NetReader, tx: UnboundedSender<HostInbound>) {
    while let Ok(Some(message)) = read_message(&mut reader).await {
        if tx.send(HostInbound::Message(source, message)).is_err() {
            return;
        }
    }
    let _ = tx.send(HostInbound::Closed(source));
}

fn validate_host_hello(message: Message) -> Result<(ProtocolProfile, SessionRole), String> {
    match message {
        Message::Hello {
            profile,
            protocol_version,
            role,
            ..
        } => {
            if protocol_version != PROTOCOL_VERSION {
                return Err("incompatible protocol version".into());
            }
            profile.validate()?;
            Ok((profile, role))
        }
        _ => Err("expected hello".into()),
    }
}

/// Send a handshake rejection without awaiting a peer that has stopped
/// reading. This is deliberately separate from the authority loop.
fn reject_host_handshake(writer: OwnedWriteHalf, reason: String) {
    tokio::spawn(async move {
        let _ = tokio::time::timeout(Duration::from_secs(1), reject(writer, &reason)).await;
    });
}

async fn prepare_host_handshake(stream: TcpStream, tx: UnboundedSender<HostHandshake>) {
    let (read_half, writer) = stream.into_split();
    let mut reader = BufReader::new(read_half);
    let handshake =
        match tokio::time::timeout(Duration::from_secs(5), read_handshake_message(&mut reader))
            .await
        {
            Ok(Ok(message)) => validate_host_hello(message),
            Ok(Err(_)) | Err(_) => Err("invalid or timed out handshake".into()),
        };

    match handshake {
        Ok((profile, role)) => {
            let _ = tx.send(HostHandshake::Ready {
                profile,
                role,
                reader,
                writer,
            });
        }
        Err(reason) => reject_host_handshake(writer, reason),
    }
    let _ = tx.send(HostHandshake::Finished);
}

fn broadcast(spectators: &[HostPeer], message: &Message) {
    for spectator in spectators {
        let _ = spectator.tx.send(message.clone());
    }
}

fn broadcast_except(spectators: &[HostPeer], excluded_id: u64, message: &Message) {
    for spectator in spectators {
        if spectator.id != excluded_id {
            let _ = spectator.tx.send(message.clone());
        }
    }
}

fn initial_clock_ms(base_minutes: u32, increment_seconds: u32) -> i64 {
    let base = i64::from(base_minutes).saturating_mul(60_000);
    if base == 0 {
        i64::from(increment_seconds).saturating_mul(1_000)
    } else {
        base
    }
}

/// Charge the host's authoritative Fischer clock up to `now`. Returns the
/// flagged side, if any. Clients may render a smooth local countdown, but only
/// this clock decides whether a LAN move is still legal.
fn charge_network_clock(
    white_ms: &mut i64,
    black_ms: &mut i64,
    running: Color,
    last_update: &mut Instant,
) -> Option<Color> {
    let elapsed = i64::try_from(last_update.elapsed().as_millis()).unwrap_or(i64::MAX);
    *last_update = Instant::now();
    let remaining = match running {
        Color::White => white_ms,
        Color::Black => black_ms,
    };
    if elapsed >= *remaining {
        *remaining = 0;
        Some(running)
    } else {
        *remaining -= elapsed;
        None
    }
}

fn apply_network_increment(white_ms: &mut i64, black_ms: &mut i64, mover: Color, inc: u32) {
    let increment = i64::from(inc).saturating_mul(1_000);
    match mover {
        Color::White => *white_ms = white_ms.saturating_add(increment),
        Color::Black => *black_ms = black_ms.saturating_add(increment),
    }
}

fn timeout_event(loser: Color) -> NetEvent {
    let mut event = NetEvent::of(NetEventKind::Resign);
    event.text = match loser {
        Color::White => "timeout:white".into(),
        Color::Black => "timeout:black".into(),
    };
    event
}

fn game_over_code(status: GameStatus) -> &'static str {
    match status {
        GameStatus::Checkmate { winner } | GameStatus::VariantWin { winner } => match winner {
            Color::White => "white_wins",
            Color::Black => "black_wins",
        },
        GameStatus::Stalemate => "stalemate",
        GameStatus::DrawFiftyMove => "draw_fifty",
        GameStatus::DrawThreefold => "draw_threefold",
        GameStatus::DrawInsufficientMaterial => "draw_insufficient",
        GameStatus::Ongoing => "ongoing",
    }
}

fn game_over_event(status: GameStatus) -> NetEvent {
    let mut event = NetEvent::of(NetEventKind::Resign);
    event.text = format!("game_over:{}", game_over_code(status));
    event
}

fn variant_state(game: &Game) -> VariantState {
    VariantState {
        white_checks: game.pos.checks[0],
        black_checks: game.pos.checks[1],
        white_hand: game.pos.hand[0],
        black_hand: game.pos.hand[1],
        promoted: game.pos.promoted,
    }
}

fn apply_variant_state(event: &mut NetEvent, state: &VariantState) -> Result<(), String> {
    state.validate()?;
    event.white_checks = state.white_checks as u32;
    event.black_checks = state.black_checks as u32;
    event.white_hand = state.white_hand.iter().map(|&count| count as u32).collect();
    event.black_hand = state.black_hand.iter().map(|&count| count as u32).collect();
    event.promoted = state.promoted;
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn spectator_start(
    white_profile: &ProtocolProfile,
    black_profile: &ProtocolProfile,
    base_minutes: u32,
    increment_seconds: u32,
    fen: String,
    variant: String,
    white_ms: i64,
    black_ms: i64,
    variant_state: VariantState,
) -> Message {
    Message::Start {
        white_profile: white_profile.clone(),
        black_profile: black_profile.clone(),
        you_are_white: false,
        role: SessionRole::Spectator,
        base_minutes,
        increment_seconds,
        fen,
        variant,
        white_ms,
        black_ms,
        variant_state,
    }
}

#[allow(clippy::too_many_arguments)]
fn connected_event(
    you_are_white: bool,
    is_spectator: bool,
    white: &ProtocolProfile,
    black: &ProtocolProfile,
    base_minutes: u32,
    increment_seconds: u32,
    fen: String,
    variant: String,
    white_ms: i64,
    black_ms: i64,
    variant_state: &VariantState,
) -> Result<NetEvent, String> {
    let mut event = NetEvent::of(NetEventKind::Connected);
    event.you_are_white = you_are_white;
    event.is_spectator = is_spectator;
    event.white_name = white.username.clone();
    event.black_name = black.username.clone();
    event.white_profile = PlayerProfileWire::from_protocol(white)?;
    event.black_profile = PlayerProfileWire::from_protocol(black)?;
    event.base_minutes = base_minutes;
    event.increment_seconds = increment_seconds;
    event.fen = fen;
    event.variant = variant;
    event.white_ms = white_ms;
    event.black_ms = black_ms;
    apply_variant_state(&mut event, variant_state)?;
    Ok(event)
}

async fn reject(mut wr: OwnedWriteHalf, reason: &str) {
    let _ = wr
        .write_all(
            Message::Reject {
                reason: reason.to_string(),
            }
            .encode()
            .as_bytes(),
        )
        .await;
}

#[allow(clippy::too_many_arguments)]
async fn host_task(
    host_wire: PlayerProfileWire,
    base: u32,
    inc: u32,
    host_white: bool,
    variant: String,
    chess960_index: u32,
    allow_spectators: bool,
    sink: &StreamSink<NetEvent>,
    session_epoch: u64,
) -> Result<(), String> {
    if !session_current(session_epoch) {
        return Ok(());
    }
    let host_profile = host_wire.to_protocol()?;
    let var = variant_from_code(&variant);
    // Fog of War intentionally withholds opponent information, so a full-board
    // spectator snapshot would leak hidden pieces and moves.
    let spectators_allowed = allow_spectators && var != Variant::FogOfWar;
    let start_fen = if var == Variant::Chess960 {
        chess_core::to_fen(&chess_core::Position::chess960(chess960_index as u16))
    } else {
        chess_core::START_FEN.to_string()
    };
    let mut game = variant_game(&start_fen, var, &VariantState::EMPTY)?;
    let mut white_ms = initial_clock_ms(base, inc);
    let mut black_ms = initial_clock_ms(base, inc);
    let timed = base != 0 || inc != 0;
    let mut clock_last_update = Instant::now();
    let mut clock_tick = tokio::time::interval(Duration::from_millis(100));
    clock_tick.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    let mut peer_heartbeat = tokio::time::interval(Duration::from_secs(3));
    peer_heartbeat.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    let mut cancel_poll = tokio::time::interval(Duration::from_millis(100));
    cancel_poll.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    let listener = bind_lan_listener().await?;
    let port = listener.local_addr().map_err(es)?.port();
    let mut advertiser = chess_net::advertise(
        HostAdvertisement {
            name: host_profile.username.clone(),
            mode: "two_player".into(),
            variant: variant.clone(),
            base_minutes: base,
            increment_seconds: inc,
            allow_spectators: spectators_allowed,
            player_count: 1,
            max_players: 2,
        },
        port,
    )
    .map_err(|e| e.to_string())?;

    let (in_tx, mut in_rx) = tokio::sync::mpsc::unbounded_channel::<HostInbound>();
    let (handshake_tx, mut handshake_rx) = tokio::sync::mpsc::unbounded_channel::<HostHandshake>();
    let (local_tx, mut local_rx) = tokio::sync::mpsc::unbounded_channel::<Message>();
    let generation = SESSION_GEN.fetch_add(1, Ordering::Relaxed) + 1;
    *lock(cmd_slot()) = Some((generation, local_tx, true));

    let mut player: Option<HostPeer> = None;
    let mut player_profile: Option<ProtocolProfile> = None;
    let mut spectators: Vec<HostPeer> = Vec::new();
    let mut next_spectator_id = 1_u64;
    let mut ended = false;
    // `true` means the host made the outstanding offer; `false` means the
    // remote player did. A response is authoritative only from the other side.
    let mut draw_offer_from_host: Option<bool> = None;
    let mut last_player_seen = Instant::now();
    let mut pending_handshakes = 0_usize;

    loop {
        if !session_current(session_epoch) {
            break;
        }
        tokio::select! {
            accepted = listener.accept() => {
                let Ok((stream, _)) = accepted else { continue };
                if pending_handshakes >= MAX_PENDING_HOST_HANDSHAKES {
                    let (_, writer) = stream.into_split();
                    reject_host_handshake(writer, "host is busy; try again shortly".into());
                    continue;
                }
                pending_handshakes += 1;
                tokio::spawn(prepare_host_handshake(stream, handshake_tx.clone()));
            }
            handshake = handshake_rx.recv() => {
                let Some(handshake) = handshake else { break };
                match handshake {
                    HostHandshake::Finished => {
                        pending_handshakes = pending_handshakes.saturating_sub(1);
                    }
                    HostHandshake::Ready {
                        profile,
                        role,
                        reader,
                        writer,
                    } => match role {
                        SessionRole::Player => {
                            if player.is_some() {
                                reject_host_handshake(
                                    writer,
                                    "a player is already connected".into(),
                                );
                                continue;
                            }
                            let (white, black) = if host_white {
                                (host_profile.clone(), profile.clone())
                            } else {
                                (profile.clone(), host_profile.clone())
                            };
                            let start = Message::Start {
                                white_profile: white.clone(),
                                black_profile: black.clone(),
                                you_are_white: !host_white,
                                role: SessionRole::Player,
                                base_minutes: base,
                                increment_seconds: inc,
                                fen: start_fen.clone(),
                                variant: variant.clone(),
                                white_ms,
                                black_ms,
                                variant_state: variant_state(&game),
                            };
                            let (peer_tx, peer_rx) = tokio::sync::mpsc::unbounded_channel();
                            tokio::spawn(host_writer(writer, peer_rx));
                            if peer_tx.send(start).is_err() {
                                continue;
                            }
                            tokio::spawn(host_reader(HostSource::Player, reader, in_tx.clone()));
                            let event = connected_event(
                                host_white,
                                false,
                                &white,
                                &black,
                                base,
                                inc,
                                start_fen.clone(),
                                variant.clone(),
                                white_ms,
                                black_ms,
                                &variant_state(&game),
                            )?;
                            if sink.add(event).is_err() {
                                break;
                            }
                            player = Some(HostPeer {
                                id: 0,
                                tx: peer_tx,
                                username: profile.username.clone(),
                            });
                            player_profile = Some(profile);
                            // Discovery is advisory, so a re-announcement
                            // failure must not interrupt an already valid game.
                            let _ = advertiser.update_player_count(2);
                            clock_last_update = Instant::now();
                            last_player_seen = Instant::now();
                        }
                        SessionRole::Spectator => {
                            if !spectators_allowed {
                                reject_host_handshake(
                                    writer,
                                    "spectators are disabled by this host".into(),
                                );
                                continue;
                            }
                            // A terminal Atomic position can have a captured king,
                            // which cannot be reconstructed from FEN by a newly
                            // joined client. More generally, a live spectator must
                            // join an active match rather than a finished result.
                            if ended || !matches!(game.status(), GameStatus::Ongoing) {
                                reject_host_handshake(
                                    writer,
                                    "the match has already ended".into(),
                                );
                                continue;
                            }
                            let Some(opponent_profile) = player_profile.as_ref() else {
                                reject_host_handshake(
                                    writer,
                                    "the match is not live yet".into(),
                                );
                                continue;
                            };
                            let id = next_spectator_id;
                            next_spectator_id = next_spectator_id.saturating_add(1);
                            let (peer_tx, peer_rx) = tokio::sync::mpsc::unbounded_channel();
                            tokio::spawn(host_writer(writer, peer_rx));
                            tokio::spawn(host_reader(
                                HostSource::Spectator(id),
                                reader,
                                in_tx.clone(),
                            ));
                            let spectator = HostPeer {
                                id,
                                tx: peer_tx,
                                username: profile.username.clone(),
                            };
                            let (white, black) = if host_white {
                                (&host_profile, opponent_profile)
                            } else {
                                (opponent_profile, &host_profile)
                            };
                            let _ = spectator.tx.send(spectator_start(
                                white,
                                black,
                                base,
                                inc,
                                chess_core::to_fen(&game.pos),
                                variant.clone(),
                                white_ms,
                                black_ms,
                                variant_state(&game),
                            ));
                            if let Some(player_peer) = player.as_ref() {
                                let _ = player_peer.tx.send(Message::SpectatorJoined {
                                    profile: profile.clone(),
                                });
                            }
                            spectators.push(spectator);
                            let mut event = NetEvent::of(NetEventKind::SpectatorJoined);
                            event.peer_profile = PlayerProfileWire::from_protocol(&profile)?;
                            event.text = profile.username;
                            let _ = sink.add(event);
                        }
                    },
                }
            }
            local = local_rx.recv() => {
                let Some(message) = local else { break };
                if matches!(message, Message::Bye) {
                    break;
                }
                let Some(player_peer) = player.as_ref() else { continue };
                match &message {
                    Message::Move { uci, .. } => {
                        if ended || !matches!(game.status(), GameStatus::Ongoing) {
                            ended = true;
                            let mut event = NetEvent::of(NetEventKind::Error);
                            event.text = "rejected local move after the match ended".into();
                            let _ = sink.add(event);
                            continue;
                        }
                        if timed {
                            if let Some(loser) = charge_network_clock(
                                &mut white_ms,
                                &mut black_ms,
                                game.pos.side,
                                &mut clock_last_update,
                            ) {
                                ended = true;
                                let timeout = Message::Timeout {
                                    loser_white: loser == Color::White,
                                };
                                let _ = player_peer.tx.send(timeout.clone());
                                broadcast(&spectators, &timeout);
                                let _ = sink.add(timeout_event(loser));
                                continue;
                            }
                        }
                        let Ok(mv) = game.pos.parse_uci(uci) else {
                            let mut event = NetEvent::of(NetEventKind::Error);
                            event.text = format!("rejected illegal local move: {uci}");
                            let _ = sink.add(event);
                            continue;
                        };
                        let mover = game.pos.side;
                        game.make_move(mv);
                        if timed {
                            apply_network_increment(&mut white_ms, &mut black_ms, mover, inc);
                            clock_last_update = Instant::now();
                        }
                        draw_offer_from_host = None;
                        let outbound = Message::Move {
                            uci: uci.clone(),
                            ply: game.ply() as u32,
                            white_ms,
                            black_ms,
                        };
                        let _ = player_peer.tx.send(outbound.clone());
                        broadcast(&spectators, &outbound);
                        let status = game.status();
                        ended = !matches!(status, GameStatus::Ongoing);
                        if ended {
                            let game_over = Message::GameOver {
                                result: game_over_code(status).into(),
                            };
                            let _ = player_peer.tx.send(game_over.clone());
                            broadcast(&spectators, &game_over);
                            let _ = sink.add(game_over_event(status));
                        }
                    }
                    Message::Resign => {
                        if ended {
                            continue;
                        }
                        ended = true;
                        draw_offer_from_host = None;
                        let _ = player_peer.tx.send(message.clone());
                        broadcast(&spectators, &message);
                    }
                    Message::DrawOffer => {
                        if !ended && draw_offer_from_host.is_none() {
                            draw_offer_from_host = Some(true);
                            let _ = player_peer.tx.send(message.clone());
                            broadcast(&spectators, &message);
                        }
                    }
                    Message::DrawResponse { accepted } => {
                        if !ended && draw_offer_from_host == Some(false) {
                            draw_offer_from_host = None;
                            ended = *accepted;
                            let _ = player_peer.tx.send(message.clone());
                            broadcast(&spectators, &message);
                        }
                    }
                    Message::SpectatorChat { .. }
                    | Message::SpectatorChatBroadcast { .. } => {
                        // The host is a player. These are only valid on a
                        // spectator socket and must never reach player peers.
                    }
                    Message::Timeout { .. } => {}
                    Message::Bye => {
                        let _ = player_peer.tx.send(message.clone());
                        broadcast(&spectators, &message);
                        break;
                    }
                    _ if !ended => {
                        let _ = player_peer.tx.send(message.clone());
                        broadcast(&spectators, &message);
                    }
                    _ => {}
                }
            }
            incoming = in_rx.recv() => {
                let Some(incoming) = incoming else { break };
                match incoming {
                    HostInbound::Closed(HostSource::Player) => {
                        let mut event = NetEvent::of(NetEventKind::Disconnected);
                        event.text = "opponent disconnected".into();
                        let _ = sink.add(event);
                        broadcast(&spectators, &Message::Bye);
                        break;
                    }
                    HostInbound::Closed(HostSource::Spectator(id)) => {
                        spectators.retain(|spectator| spectator.id != id);
                    }
                    HostInbound::Message(HostSource::Spectator(id), message) => {
                        match message {
                            Message::SpectatorChat { text } => {
                                let text = text.trim();
                                if text.is_empty() || text.len() > MAX_CHAT_BYTES {
                                    if let Some(spectator) = spectators.iter().find(|spectator| spectator.id == id) {
                                        let _ = spectator.tx.send(Message::Reject {
                                            reason: "spectator chat message exceeds the LAN limit".into(),
                                        });
                                    }
                                    continue;
                                }
                                let Some(sender) = spectators
                                    .iter()
                                    .find(|spectator| spectator.id == id)
                                    .map(|spectator| spectator.username.clone())
                                else {
                                    continue;
                                };
                                // The source adds its own message optimistically;
                                // excluding it prevents a duplicate bubble.
                                broadcast_except(
                                    &spectators,
                                    id,
                                    &Message::SpectatorChatBroadcast {
                                        sender,
                                        text: text.to_owned(),
                                    },
                                );
                            }
                            Message::Ping { t } => {
                                if let Some(spectator) = spectators.iter().find(|spectator| spectator.id == id) {
                                    let _ = spectator.tx.send(Message::Pong { t });
                                }
                            }
                            Message::Pong { .. } | Message::Bye => {}
                            _ => {
                                if let Some(spectator) = spectators.iter().find(|spectator| spectator.id == id) {
                                    let _ = spectator.tx.send(Message::Reject {
                                        reason: "spectators are read-only".into(),
                                    });
                                }
                            }
                        }
                    }
                    HostInbound::Message(HostSource::Player, message) => {
                        last_player_seen = Instant::now();
                        let Some(player_peer) = player.as_ref() else { continue };
                        match message {
                            Message::Move { uci, ply, .. } => {
                                if ended || !matches!(game.status(), GameStatus::Ongoing) {
                                    ended = true;
                                    let _ = player_peer.tx.send(Message::Reject {
                                        reason: "the match has already ended".into(),
                                    });
                                    continue;
                                }
                                if timed {
                                    if let Some(loser) = charge_network_clock(
                                        &mut white_ms,
                                        &mut black_ms,
                                        game.pos.side,
                                        &mut clock_last_update,
                                    ) {
                                        ended = true;
                                        let timeout = Message::Timeout {
                                            loser_white: loser == Color::White,
                                        };
                                        let _ = player_peer.tx.send(timeout.clone());
                                        broadcast(&spectators, &timeout);
                                        let _ = sink.add(timeout_event(loser));
                                        continue;
                                    }
                                }
                                let Ok(mv) = game.pos.parse_uci(&uci) else {
                                    let mut event = NetEvent::of(NetEventKind::Error);
                                    event.text = format!("rejected illegal/out-of-turn move: {uci}");
                                    let _ = sink.add(event);
                                    let _ = player_peer.tx.send(Message::Reject {
                                        reason: "host rejected an illegal or out-of-turn move".into(),
                                    });
                                    broadcast(&spectators, &Message::Bye);
                                    break;
                                };
                                let mover = game.pos.side;
                                game.make_move(mv);
                                if timed {
                                    apply_network_increment(&mut white_ms, &mut black_ms, mover, inc);
                                    clock_last_update = Instant::now();
                                }
                                draw_offer_from_host = None;
                                let outbound = Message::Move { uci: uci.clone(), ply, white_ms, black_ms };
                                broadcast(&spectators, &outbound);
                                let mut event = NetEvent::of(NetEventKind::Move);
                                event.uci = uci;
                                event.white_ms = white_ms;
                                event.black_ms = black_ms;
                                let _ = sink.add(event);
                                let status = game.status();
                                ended = !matches!(status, GameStatus::Ongoing);
                                if ended {
                                    let game_over = Message::GameOver {
                                        result: game_over_code(status).into(),
                                    };
                                    let _ = player_peer.tx.send(game_over.clone());
                                    broadcast(&spectators, &game_over);
                                    let _ = sink.add(game_over_event(status));
                                }
                            }
                            Message::Resign => {
                                if ended {
                                    continue;
                                }
                                ended = true;
                                draw_offer_from_host = None;
                                broadcast(&spectators, &Message::Resign);
                                let _ = sink.add(NetEvent::of(NetEventKind::Resign));
                            }
                            Message::DrawOffer => {
                                if !ended && draw_offer_from_host.is_none() {
                                    draw_offer_from_host = Some(false);
                                    broadcast(&spectators, &Message::DrawOffer);
                                    let _ = sink.add(NetEvent::of(NetEventKind::DrawOffer));
                                }
                            }
                            Message::DrawResponse { accepted } => {
                                if !ended && draw_offer_from_host == Some(true) {
                                    draw_offer_from_host = None;
                                    ended = accepted;
                                    broadcast(&spectators, &Message::DrawResponse { accepted });
                                    let mut event = NetEvent::of(NetEventKind::DrawResponse);
                                    event.draw_accepted = accepted;
                                    let _ = sink.add(event);
                                } else {
                                    let _ = player_peer.tx.send(Message::Reject {
                                        reason: "there is no pending draw offer to answer".into(),
                                    });
                                }
                            }
                            Message::SpectatorChat { .. }
                            | Message::SpectatorChatBroadcast { .. } => {
                                // A player cannot send or relay spectator chat.
                            }
                            Message::Chat { text } => {
                                if text.len() > MAX_CHAT_BYTES {
                                    let _ = player_peer.tx.send(Message::Reject {
                                        reason: "chat message exceeds the LAN limit".into(),
                                    });
                                    continue;
                                }
                                let outbound = Message::Chat { text: text.clone() };
                                broadcast(&spectators, &outbound);
                                let mut event = NetEvent::of(NetEventKind::Chat);
                                event.text = text;
                                let _ = sink.add(event);
                            }
                            Message::Ping { t } => {
                                let _ = player_peer.tx.send(Message::Pong { t });
                            }
                            Message::Pong { .. } => {}
                            Message::Bye => {
                                let mut event = NetEvent::of(NetEventKind::Disconnected);
                                event.text = "opponent left".into();
                                let _ = sink.add(event);
                                broadcast(&spectators, &Message::Bye);
                                break;
                            }
                            _ => {}
                        }
                    }
                }
            }
            _ = clock_tick.tick(), if timed && player.is_some() && !ended => {
                if let Some(loser) = charge_network_clock(
                    &mut white_ms,
                    &mut black_ms,
                    game.pos.side,
                    &mut clock_last_update,
                ) {
                    ended = true;
                    draw_offer_from_host = None;
                    let timeout = Message::Timeout {
                        loser_white: loser == Color::White,
                    };
                    if let Some(player_peer) = player.as_ref() {
                        let _ = player_peer.tx.send(timeout.clone());
                    }
                    broadcast(&spectators, &timeout);
                    let _ = sink.add(timeout_event(loser));
                }
            }
            _ = peer_heartbeat.tick(), if player.is_some() && !ended => {
                if last_player_seen.elapsed() > Duration::from_secs(12) {
                    let mut event = NetEvent::of(NetEventKind::Disconnected);
                    event.text = "opponent disconnected (timeout)".into();
                    let _ = sink.add(event);
                    broadcast(&spectators, &Message::Bye);
                    break;
                }
                if let Some(player_peer) = player.as_ref() {
                    let _ = player_peer.tx.send(Message::Ping { t: 0 });
                }
            }
            _ = cancel_poll.tick() => {}
            _ = session_cancel().notified() => {
                if !session_current(session_epoch) {
                    break;
                }
            }
        }
    }

    let mut slot = lock(cmd_slot());
    if matches!(*slot, Some((owner, _, _)) if owner == generation) {
        *slot = None;
    }
    Ok(())
}

async fn join_task(
    addr: String,
    wire_profile: PlayerProfileWire,
    requested_role: SessionRole,
    sink: &StreamSink<NetEvent>,
    session_epoch: u64,
) -> Result<(), String> {
    if !session_current(session_epoch) {
        return Ok(());
    }
    let profile = wire_profile.to_protocol()?;
    let Some(stream) = join_connect(&addr, session_epoch).await? else {
        return Ok(());
    };
    let (rd, mut wr) = stream.into_split();
    let mut reader = BufReader::new(rd);
    if !join_write(
        &mut wr,
        Message::Hello {
            profile,
            protocol_version: PROTOCOL_VERSION,
            role: requested_role,
            base_minutes: 0,
            increment_seconds: 0,
        },
        session_epoch,
    )
    .await?
    {
        return Ok(());
    }

    let Some(start) = join_handshake(&mut reader, session_epoch).await? else {
        return Ok(());
    };
    let (
        white_profile,
        black_profile,
        you_are_white,
        role,
        base,
        inc,
        fen,
        variant,
        white_ms,
        black_ms,
        variant_state,
    ) = match start {
        Message::Start {
            white_profile,
            black_profile,
            you_are_white,
            role,
            base_minutes,
            increment_seconds,
            fen,
            variant,
            white_ms,
            black_ms,
            variant_state,
        } => (
            white_profile,
            black_profile,
            you_are_white,
            role,
            base_minutes,
            increment_seconds,
            fen,
            variant,
            white_ms,
            black_ms,
            variant_state,
        ),
        Message::Reject { reason } => return Err(reason),
        Message::Bye => return Err("host rejected the connection".into()),
        _ => return Err("expected start".into()),
    };
    if role != requested_role {
        return Err("host returned an unexpected session role".into());
    }
    if !session_current(session_epoch) {
        return Ok(());
    }
    let event = connected_event(
        you_are_white,
        role == SessionRole::Spectator,
        &white_profile,
        &black_profile,
        base,
        inc,
        fen.clone(),
        variant.clone(),
        white_ms,
        black_ms,
        &variant_state,
    )?;
    if sink.add(event).is_err() {
        return Ok(());
    }
    drive(
        reader,
        wr,
        sink,
        variant_game(&fen, variant_from_code(&variant), &variant_state)?,
        role == SessionRole::Player,
        session_epoch,
    )
    .await;
    Ok(())
}

/// The connection event loop: relays commands, validates incoming moves, and
/// runs a heartbeat to detect disconnects.
async fn drive(
    mut reader: NetReader,
    mut wr: OwnedWriteHalf,
    sink: &StreamSink<NetEvent>,
    mut game: Game,
    actions_allowed: bool,
    session_epoch: u64,
) {
    if !session_current(session_epoch) {
        return;
    }
    let (tx, mut cmd_rx): (UnboundedSender<Message>, UnboundedReceiver<Message>) =
        tokio::sync::mpsc::unbounded_channel();
    let gen = SESSION_GEN.fetch_add(1, Ordering::Relaxed) + 1;
    *lock(cmd_slot()) = Some((gen, tx, actions_allowed));

    let mut heartbeat = tokio::time::interval(Duration::from_secs(3));
    heartbeat.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    let mut last_seen = Instant::now();
    let mut cancel_poll = tokio::time::interval(Duration::from_millis(100));
    cancel_poll.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    loop {
        if !session_current(session_epoch) {
            break;
        }
        tokio::select! {
            _ = heartbeat.tick() => {
                if last_seen.elapsed() > Duration::from_secs(12) {
                    let mut ev = NetEvent::of(NetEventKind::Disconnected);
                    ev.text = "opponent disconnected (timeout)".into();
                    let _ = sink.add(ev);
                    break;
                }
                if wr.write_all(Message::Ping { t: 0 }.encode().as_bytes()).await.is_err() {
                    break;
                }
            }
            cmd = cmd_rx.recv() => {
                let Some(msg) = cmd else { break };
                if let Message::Move { ref uci, .. } = msg {
                    if let Ok(mv) = game.pos.parse_uci(uci) {
                        game.make_move(mv);
                    }
                }
                let bye = matches!(msg, Message::Bye);
                if wr.write_all(msg.encode().as_bytes()).await.is_err() {
                    break;
                }
                if bye {
                    break;
                }
            }
            message = read_message(&mut reader) => {
                match message {
                    Ok(Some(message)) => {
                        last_seen = Instant::now();
                        if !handle_incoming(message, &mut game, sink, &mut wr, !actions_allowed).await {
                            break;
                        }
                    }
                    Ok(None) => {
                        let mut ev = NetEvent::of(NetEventKind::Disconnected);
                        ev.text = "connection closed".into();
                        let _ = sink.add(ev);
                        break;
                    }
                    Err(reason) => {
                        let mut ev = NetEvent::of(NetEventKind::Error);
                        ev.text = reason;
                        let _ = sink.add(ev);
                        break;
                    }
                }
            }
            _ = cancel_poll.tick() => {}
            _ = session_cancel().notified() => {
                if !session_current(session_epoch) {
                    break;
                }
            }
        }
    }
    // Only clear the slot if this session still owns it (don't wipe a newer one).
    let mut slot = lock(cmd_slot());
    if matches!(*slot, Some((g, _, _)) if g == gen) {
        *slot = None;
    }
}

/// Returns false when the loop should stop (e.g. peer said Bye).
async fn handle_incoming(
    msg: Message,
    game: &mut Game,
    sink: &StreamSink<NetEvent>,
    wr: &mut OwnedWriteHalf,
    is_spectator: bool,
) -> bool {
    match msg {
        Message::Move {
            uci,
            white_ms,
            black_ms,
            ..
        } => match game.pos.parse_uci(&uci) {
            Ok(mv) => {
                game.make_move(mv);
                let mut ev = NetEvent::of(NetEventKind::Move);
                ev.uci = uci;
                ev.white_ms = white_ms;
                ev.black_ms = black_ms;
                let _ = sink.add(ev);
            }
            Err(_) => {
                let mut ev = NetEvent::of(NetEventKind::Error);
                ev.text = format!("rejected illegal/out-of-turn move: {uci}");
                let _ = sink.add(ev);
            }
        },
        Message::Resign => {
            let _ = sink.add(NetEvent::of(NetEventKind::Resign));
        }
        Message::Timeout { loser_white } => {
            let loser = if loser_white {
                Color::White
            } else {
                Color::Black
            };
            let _ = sink.add(timeout_event(loser));
        }
        Message::GameOver { result } => {
            let mut event = NetEvent::of(NetEventKind::Resign);
            event.text = format!("game_over:{result}");
            let _ = sink.add(event);
        }
        Message::DrawOffer => {
            let _ = sink.add(NetEvent::of(NetEventKind::DrawOffer));
        }
        Message::DrawResponse { accepted } => {
            let mut ev = NetEvent::of(NetEventKind::DrawResponse);
            ev.draw_accepted = accepted;
            let _ = sink.add(ev);
        }
        Message::Chat { text } => {
            if text.len() > MAX_CHAT_BYTES {
                let _ = wr
                    .write_all(
                        Message::Reject {
                            reason: "chat message exceeds the LAN limit".into(),
                        }
                        .encode()
                        .as_bytes(),
                    )
                    .await;
                return false;
            }
            let mut ev = NetEvent::of(NetEventKind::Chat);
            ev.text = text;
            let _ = sink.add(ev);
        }
        Message::SpectatorChatBroadcast { sender, text } => {
            // This route is private to spectator transports. Authenticate the
            // host-supplied display name defensively before it reaches Flutter.
            if is_spectator
                && !text.trim().is_empty()
                && text.len() <= MAX_CHAT_BYTES
                && ProtocolProfile::from_avatar_bytes(sender.clone(), &[]).is_ok()
            {
                let mut ev = NetEvent::of(NetEventKind::SpectatorChat);
                ev.sender = sender;
                ev.text = text;
                let _ = sink.add(ev);
            }
        }
        Message::SpectatorChat { .. } => {
            // Only the host accepts raw spectator chat messages.
        }
        Message::Ping { t } => {
            let _ = wr.write_all(Message::Pong { t }.encode().as_bytes()).await;
        }
        Message::Pong { .. } => {}
        Message::SpectatorJoined { profile } => {
            let mut ev = NetEvent::of(NetEventKind::SpectatorJoined);
            match PlayerProfileWire::from_protocol(&profile) {
                Ok(peer_profile) => {
                    ev.text = peer_profile.username.clone();
                    ev.peer_profile = peer_profile;
                    let _ = sink.add(ev);
                }
                Err(reason) => {
                    let mut error = NetEvent::of(NetEventKind::Error);
                    error.text = reason;
                    let _ = sink.add(error);
                }
            }
        }
        Message::Reject { reason } => {
            let mut ev = NetEvent::of(NetEventKind::Error);
            ev.text = reason;
            let _ = sink.add(ev);
            return false;
        }
        Message::Bye => {
            let mut ev = NetEvent::of(NetEventKind::Disconnected);
            ev.text = "opponent left".into();
            let _ = sink.add(ev);
            return false;
        }
        _ => {}
    }
    true
}

/// Read one newline-delimited protocol message without allowing an attacker to
/// allocate an unbounded `String` before the size check. `lines()` performs
/// that allocation internally, so all LAN paths use this bounded reader.
async fn read_message(reader: &mut NetReader) -> Result<Option<Message>, String> {
    let mut line = Vec::new();
    loop {
        let available = reader.fill_buf().await.map_err(es)?;
        if available.is_empty() {
            return if line.is_empty() {
                Ok(None)
            } else {
                Err("connection closed mid-message".into())
            };
        }
        let available_len = available.len();
        let newline = available.iter().position(|&byte| byte == b'\n');
        let take = newline.unwrap_or(available_len);
        if line.len().saturating_add(take) > MAX_MESSAGE_BYTES {
            // The caller closes this connection on error; consume the currently
            // borrowed buffer before returning so the reader remains coherent.
            reader.consume(available_len);
            return Err("LAN message exceeds size limit".into());
        }
        line.extend_from_slice(&available[..take]);
        reader.consume(if newline.is_some() { take + 1 } else { take });
        if newline.is_some() {
            let text = std::str::from_utf8(&line)
                .map_err(|_| "LAN message is not valid UTF-8".to_string())?;
            return Message::decode(text)
                .map(Some)
                .map_err(|error| error.to_string());
        }
    }
}

async fn read_handshake_message(reader: &mut NetReader) -> Result<Message, String> {
    read_message(reader)
        .await?
        .ok_or_else(|| "connection closed during handshake".into())
}

fn es<E: std::fmt::Display>(e: E) -> String {
    e.to_string()
}

/// Bind one of the documented LAN host ports, skipping ports already used by
/// another local instance or a companion application.
async fn bind_lan_listener() -> Result<TcpListener, String> {
    let mut last_in_use = None;
    for port in LAN_PORT_MIN..=LAN_PORT_MAX {
        match TcpListener::bind(("0.0.0.0", port)).await {
            Ok(listener) => return Ok(listener),
            Err(error) if error.kind() == std::io::ErrorKind::AddrInUse => {
                last_in_use = Some(error);
            }
            Err(error) => return Err(format!("failed to bind LAN port {port}: {error}")),
        }
    }

    let detail = last_in_use
        .map(|error| error.to_string())
        .unwrap_or_else(|| "no ports were attempted".into());
    Err(format!(
        "no free LAN host ports in {LAN_PORT_MIN}-{LAN_PORT_MAX}: {detail}"
    ))
}

// ---- Commands (sent from Dart) -----------------------------------------

fn send(msg: Message) {
    if let Some((_, tx, true)) = lock(cmd_slot()).as_ref() {
        let _ = tx.send(msg);
    }
}

fn send_spectator(msg: Message) {
    if let Some((_, tx, false)) = lock(cmd_slot()).as_ref() {
        let _ = tx.send(msg);
        return;
    }
    if let Some((_, tx, SessionRole::Spectator)) = lock(four_client_out()).as_ref() {
        let _ = tx.send(msg);
    }
}

fn send_leave() {
    if let Some((_, tx, _)) = lock(cmd_slot()).as_ref() {
        let _ = tx.send(Message::Bye);
        return;
    }
    if let Some((_, tx, _)) = lock(four_client_out()).as_ref() {
        let _ = tx.send(Message::Bye);
    }
}

#[frb(sync)]
pub fn net_send_move(uci: String, white_ms: i64, black_ms: i64) {
    send(Message::Move {
        uci,
        ply: 0,
        white_ms,
        black_ms,
    });
}

#[frb(sync)]
pub fn net_resign() {
    send(Message::Resign);
}

#[frb(sync)]
pub fn net_offer_draw() {
    send(Message::DrawOffer);
}

#[frb(sync)]
pub fn net_respond_draw(accept: bool) {
    send(Message::DrawResponse { accepted: accept });
}

#[frb(sync)]
pub fn net_send_chat(text: String) {
    let text = text.trim();
    if text.is_empty() || text.len() > MAX_CHAT_BYTES {
        return;
    }
    send(Message::Chat {
        text: text.to_owned(),
    });
}

#[frb(sync)]
pub fn net_send_spectator_chat(text: String) {
    let text = text.trim();
    if text.is_empty() || text.len() > MAX_CHAT_BYTES {
        return;
    }
    send_spectator(Message::SpectatorChat {
        text: text.to_owned(),
    });
}

#[frb(sync)]
pub fn net_leave() {
    send_leave(); // tell a connected peer (live game)
    cancel_sessions(); // abort a still-waiting host / break every live session
}

// ===== Bughouse: host-authoritative star (4 seats, up to 3 joiners) =====
//
// Seats: 0=A-White, 1=A-Black, 2=B-White, 3=B-Black. Teams: 1 = {0,3}, 2 = {1,2}.
// The host runs both boards as the authority: it validates each board-tagged
// move, routes the captured piece to the partner's reserve, and broadcasts the
// move + pass + result to every client. Clients mirror; they send only their
// own seats' input. Clock values are client-reported and relayed (not host-
// authoritative on time), matching the 1-peer relay.

fn seat_board(seat: u8) -> usize {
    if seat < 2 {
        0
    } else {
        1
    }
}

fn seat_index(board: usize, color: Color) -> u8 {
    debug_assert!(board < 2, "bughouse has exactly two boards");
    board as u8 * 2 + if color == Color::White { 0 } else { 1 }
}

fn bug_team(seat: u8) -> u8 {
    if seat == 0 || seat == 3 {
        1
    } else {
        2
    }
}

fn color_u8(c: Color) -> u32 {
    if c == Color::White {
        0
    } else {
        1
    }
}

fn piece_u8(p: Piece) -> u32 {
    match p {
        Piece::Pawn => 0,
        Piece::Knight => 1,
        Piece::Bishop => 2,
        Piece::Rook => 3,
        Piece::Queen => 4,
        Piece::King => 0,
    }
}

/// Partner feed: a capture by `mover` on `board` lands in the other board's
/// opposite-colour reserve (the partner's hand).
fn feed_target(board: usize, mover: Color) -> (usize, Color) {
    (
        1 - board,
        if mover == Color::White {
            Color::Black
        } else {
            Color::White
        },
    )
}

fn bug_game() -> Game {
    let mut pos = chess_core::parse_fen(chess_core::START_FEN).expect("start fen");
    pos.variant = Variant::Bughouse;
    pos.hash = pos.compute_hash();
    Game::from_position(pos)
}

/// The piece a move makes available to pass (demoted to pawn if it was promoted).
fn bug_passable(pos: &chess_core::Position, m: chess_core::Move) -> Option<Piece> {
    if m.is_drop() {
        return None;
    }
    let cap_sq = if m.is_ep() {
        if pos.side == Color::White {
            m.to() - 8
        } else {
            m.to() + 8
        }
    } else if m.is_capture() {
        m.to()
    } else {
        return None;
    };
    let (_, cp) = pos.piece_at(cap_sq)?;
    Some(if pos.promoted & (1u64 << cap_sq) != 0 {
        Piece::Pawn
    } else {
        cp
    })
}

type BugInbound = Mutex<Option<(u64, UnboundedSender<(Option<usize>, Message)>)>>;
fn bug_inbound() -> &'static BugInbound {
    static S: OnceLock<BugInbound> = OnceLock::new();
    S.get_or_init(|| Mutex::new(None))
}

type BugClientOut = Mutex<Option<(u64, UnboundedSender<Message>)>>;
fn bug_client_out() -> &'static BugClientOut {
    static S: OnceLock<BugClientOut> = OnceLock::new();
    S.get_or_init(|| Mutex::new(None))
}

static BUG_ASSIGN: Mutex<Option<Vec<i32>>> = Mutex::new(None);
fn bug_assign_notify() -> &'static tokio::sync::Notify {
    static N: OnceLock<tokio::sync::Notify> = OnceLock::new();
    N.get_or_init(tokio::sync::Notify::new)
}

type BugPeer = (UnboundedSender<Message>, ProtocolProfile);

fn bug_broadcast(peers: &[BugPeer], msg: &Message) {
    for (tx, _) in peers {
        let _ = tx.send(msg.clone());
    }
}

/// A validated lobby connection whose first message was a player `Hello`.
/// Keeping this separate from the authority loop lets a slow TCP client spend
/// its handshake timeout in a task without pausing a live match.
struct PendingLobbyPeer {
    reader: NetReader,
    writer: OwnedWriteHalf,
    profile: ProtocolProfile,
}

/// Validate a player-only lobby handshake without making the host authority
/// await network input. Both Bughouse and four-player chess use this path.
async fn lobby_player_handshake(
    stream: TcpStream,
    spectator_reason: &'static str,
) -> Option<PendingLobbyPeer> {
    let (rd, wr) = stream.into_split();
    let mut reader = BufReader::new(rd);
    let hello =
        match tokio::time::timeout(Duration::from_secs(5), read_handshake_message(&mut reader))
            .await
        {
            Ok(Ok(message)) => message,
            Ok(Err(_)) | Err(_) => {
                reject_host_handshake(wr, "invalid or timed out handshake".into());
                return None;
            }
        };
    let profile = match hello {
        Message::Hello {
            profile,
            protocol_version,
            role,
            ..
        } => {
            if protocol_version != PROTOCOL_VERSION {
                reject_host_handshake(wr, "incompatible protocol version".into());
                return None;
            }
            if role != SessionRole::Player {
                reject_host_handshake(wr, spectator_reason.into());
                return None;
            }
            if let Err(reason) = profile.validate() {
                reject_host_handshake(wr, reason);
                return None;
            }
            profile
        }
        _ => {
            reject_host_handshake(wr, "expected player hello".into());
            return None;
        }
    };
    Some(PendingLobbyPeer {
        reader,
        writer: wr,
        profile,
    })
}

/// LAN Bughouse requires four distinct devices. Keeping this in the authority,
/// rather than only the lobby UI, prevents a host from recreating the removed
/// multi-seat mode through a crafted bridge call.
fn valid_network_seat_owners(seat_owner: &[i32], peer_count: usize) -> bool {
    if peer_count != 3 || seat_owner.len() != 4 {
        return false;
    }
    let mut seen = [false; 4]; // host=-1 -> 0, joiners 0..2 -> 1..3
    for &owner in seat_owner {
        let index = match owner {
            -1 => 0,
            0..=2 => owner as usize + 1,
            _ => return false,
        };
        if std::mem::replace(&mut seen[index], true) {
            return false;
        }
    }
    seen.into_iter().all(|assigned| assigned)
}

/// Host a Bughouse match: advertise (name prefixed "[BH]"), accept up to 3
/// joiners into a lobby, then — once the host assigns seats — run the authority.
pub fn net_host_bughouse(
    profile: PlayerProfileWire,
    base_minutes: u32,
    increment_seconds: u32,
    sink: StreamSink<NetEvent>,
) -> Result<(), String> {
    let epoch = begin_session();
    runtime().block_on(async move {
        if let Err(e) = bug_host_task(profile, base_minutes, increment_seconds, &sink, epoch).await
        {
            let mut ev = NetEvent::of(NetEventKind::Error);
            ev.text = e;
            let _ = sink.add(ev);
        }
        let _ = sink.add(NetEvent::of(NetEventKind::Disconnected));
    });
    Ok(())
}

async fn bug_host_task(
    host_wire: PlayerProfileWire,
    base: u32,
    inc: u32,
    sink: &StreamSink<NetEvent>,
    session_epoch: u64,
) -> Result<(), String> {
    if !session_current(session_epoch) {
        return Ok(());
    }
    let host_profile = host_wire.to_protocol()?;
    let listener = bind_lan_listener().await?;
    let port = listener.local_addr().map_err(es)?.port();
    let mut advertiser = chess_net::advertise(
        HostAdvertisement {
            name: host_profile.username.clone(),
            mode: "bughouse".into(),
            variant: "bughouse".into(),
            base_minutes: base,
            increment_seconds: inc,
            allow_spectators: false,
            player_count: 1,
            max_players: 4,
        },
        port,
    )
    .map_err(|e| e.to_string())?;

    let (in_tx, mut in_rx) = tokio::sync::mpsc::unbounded_channel::<(Option<usize>, Message)>();
    let (handshake_tx, mut handshake_rx) =
        tokio::sync::mpsc::unbounded_channel::<Option<PendingLobbyPeer>>();
    let gen = SESSION_GEN.fetch_add(1, Ordering::Relaxed) + 1;
    *lock(bug_inbound()) = Some((gen, in_tx.clone()));

    let mut peers: Vec<BugPeer> = Vec::new();
    let mut games = [bug_game(), bug_game()];
    let mut seat_owner: [Option<usize>; 4] = [None; 4]; // None = host holds the seat
    let mut started = false;
    let mut ended = false;
    let mut pending_handshakes = 0_usize;
    let mut cancel_poll = tokio::time::interval(Duration::from_millis(100));
    cancel_poll.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    loop {
        if !session_current(session_epoch) {
            break;
        }
        tokio::select! {
            r = listener.accept(), if !started && peers.len().saturating_add(pending_handshakes) < 3 => {
                let stream = match r { Ok((s, _)) => s, Err(_) => continue };
                pending_handshakes += 1;
                let tx = handshake_tx.clone();
                tokio::spawn(async move {
                    let _ = tx.send(lobby_player_handshake(
                        stream,
                        "Bughouse does not support spectators",
                    ).await);
                });
            }
            handshake = handshake_rx.recv(), if !started && pending_handshakes > 0 => {
                let Some(handshake) = handshake else { break };
                pending_handshakes = pending_handshakes.saturating_sub(1);
                let Some(PendingLobbyPeer { reader, writer: wr, profile: peer_profile }) = handshake else {
                    continue;
                };
                if peers.len() >= 3 {
                    reject_host_handshake(wr, "Bughouse lobby is full".into());
                    continue;
                }
                let idx = peers.len();
                let (ptx, prx) = tokio::sync::mpsc::unbounded_channel::<Message>();
                tokio::spawn(bug_writer(wr, prx));
                tokio::spawn(bug_reader(idx, reader, in_tx.clone()));
                peers.push((ptx, peer_profile.clone()));
                let _ = advertiser.update_player_count(1 + peers.len() as u32);
                let mut ev = NetEvent::of(NetEventKind::BugJoin);
                ev.text = peer_profile.username.clone();
                ev.peer_profile = PlayerProfileWire::from_protocol(&peer_profile)?;
                ev.seat = idx as u32; // connection index (seats assigned at start)
                let _ = sink.add(ev);
            }
            _ = bug_assign_notify().notified(), if !started => {
                let Some(owner) = lock(&BUG_ASSIGN).take() else { continue };
                if !valid_network_seat_owners(&owner, peers.len()) { continue; }
                for (seat, owner_index) in owner.iter().enumerate() {
                    seat_owner[seat] = if *owner_index < 0 {
                        None
                    } else {
                        Some(*owner_index as usize)
                    };
                }
                let seat_profiles: Vec<ProtocolProfile> = (0..4)
                    .map(|s| match seat_owner[s] {
                        None => host_profile.clone(),
                        Some(i) => peers.get(i).map(|p| p.1.clone()).unwrap_or_else(|| host_profile.clone()),
                    })
                    .collect();
                let names: Vec<String> = seat_profiles
                    .iter()
                    .map(|profile| profile.username.clone())
                    .collect();
                for (i, (tx, _)) in peers.iter().enumerate() {
                    let my: Vec<u8> =
                        (0..4u8).filter(|&s| seat_owner[s as usize] == Some(i)).collect();
                    let _ = tx.send(Message::BugStart {
                        seats: seat_profiles.clone(),
                        your_seats: my,
                        base_minutes: base,
                        increment_seconds: inc,
                    });
                }
                let host_seats: Vec<u32> =
                    (0..4u32).filter(|&s| seat_owner[s as usize].is_none()).collect();
                let mut ev = NetEvent::of(NetEventKind::BugStart);
                ev.your_seats = host_seats;
                ev.seats = names;
                ev.seat_profiles = seat_profiles
                    .iter()
                    .map(PlayerProfileWire::from_protocol)
                    .collect::<Result<Vec<_>, _>>()?;
                ev.base_minutes = base;
                ev.increment_seconds = inc;
                let _ = sink.add(ev);
                started = true;
            }
            msg = in_rx.recv() => {
                let Some((from, m)) = msg else { break };
                if !started && from.is_some() && matches!(&m, Message::Bye) {
                    let mut event = NetEvent::of(NetEventKind::Error);
                    event.text = "a lobby player disconnected; host a new match".into();
                    let _ = sink.add(event);
                    break;
                }
                if started && !ended {
                    bug_authority(from, m, &mut games, &seat_owner, &peers, sink, &mut ended);
                }
            }
            _ = cancel_poll.tick() => {}
            _ = session_cancel().notified() => {
                if !session_current(session_epoch) {
                    break;
                }
            }
        }
    }

    let mut slot = lock(bug_inbound());
    if matches!(*slot, Some((g, _)) if g == gen) {
        *slot = None;
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn bug_authority(
    from: Option<usize>,
    m: Message,
    games: &mut [Game; 2],
    seat_owner: &[Option<usize>; 4],
    peers: &[BugPeer],
    sink: &StreamSink<NetEvent>,
    ended: &mut bool,
) {
    match m {
        Message::BugMove {
            board,
            uci,
            white_ms,
            black_ms,
        } => {
            let b = board as usize;
            if b > 1 {
                return;
            }
            let stm = games[b].pos.side;
            let seat = seat_index(b, stm);
            let owner = seat_owner[seat as usize];
            let allowed = matches!((from, owner), (None, None))
                || matches!((from, owner), (Some(i), Some(j)) if i == j);
            if !allowed {
                return; // not this sender's seat / turn
            }
            let Ok(mv) = games[b].pos.parse_uci(&uci) else {
                return;
            };
            let passable = bug_passable(&games[b].pos, mv);
            games[b].make_move(mv);

            bug_broadcast(
                peers,
                &Message::BugMove {
                    board,
                    uci: uci.clone(),
                    white_ms,
                    black_ms,
                },
            );
            let mut ev = NetEvent::of(NetEventKind::BugMove);
            ev.board = board as u32;
            ev.uci = uci;
            ev.white_ms = white_ms;
            ev.black_ms = black_ms;
            let _ = sink.add(ev);

            if let Some(p) = passable {
                let (ob, oc) = feed_target(b, stm);
                games[ob].pos.add_to_hand(oc, p);
                bug_broadcast(
                    peers,
                    &Message::BugPass {
                        to_board: ob as u8,
                        to_color: color_u8(oc) as u8,
                        piece: piece_u8(p) as u8,
                    },
                );
                let mut ev = NetEvent::of(NetEventKind::BugPass);
                ev.to_board = ob as u32;
                ev.to_color = color_u8(oc);
                ev.piece = piece_u8(p);
                let _ = sink.add(ev);
            }

            if let Some((team, board_ended)) = bug_check_end(games) {
                bug_finish(team, board_ended, peers, sink, ended);
            }
        }
        Message::BugResign { seat } => {
            if seat >= 4 {
                return;
            }
            let owner = seat_owner[seat as usize];
            let allowed = matches!((from, owner), (None, None))
                || matches!((from, owner), (Some(i), Some(j)) if i == j);
            if !allowed {
                return;
            }
            bug_finish(
                3 - bug_team(seat),
                seat_board(seat) as u8,
                peers,
                sink,
                ended,
            );
        }
        Message::Bye => {
            if let Some(i) = from {
                if let Some(s) = (0..4u8).find(|&s| seat_owner[s as usize] == Some(i)) {
                    bug_finish(3 - bug_team(s), seat_board(s) as u8, peers, sink, ended);
                }
            }
        }
        _ => {}
    }
}

/// If either board has ended, the winning team + which board ended.
fn bug_check_end(games: &mut [Game; 2]) -> Option<(u8, u8)> {
    for (b, game) in games.iter_mut().enumerate() {
        let loser = match game.status() {
            GameStatus::Checkmate { winner } | GameStatus::VariantWin { winner } => {
                Some(winner.opp())
            }
            GameStatus::Ongoing => None,
            _ => Some(game.pos.side), // stalemate / draws → side to move loses
        };
        if let Some(lc) = loser {
            let team = bug_team(seat_index(b, lc));
            return Some((3 - team, b as u8));
        }
    }
    None
}

fn bug_finish(
    team: u8,
    board: u8,
    peers: &[BugPeer],
    sink: &StreamSink<NetEvent>,
    ended: &mut bool,
) {
    if *ended {
        return;
    }
    *ended = true;
    bug_broadcast(
        peers,
        &Message::BugResult {
            winning_team: team,
            reason: "match over".into(),
            board,
        },
    );
    let mut ev = NetEvent::of(NetEventKind::BugResult);
    ev.winning_team = team as u32;
    ev.board = board as u32;
    let _ = sink.add(ev);
}

async fn bug_writer(mut wr: OwnedWriteHalf, mut rx: UnboundedReceiver<Message>) {
    while let Some(m) = rx.recv().await {
        if wr.write_all(m.encode().as_bytes()).await.is_err() {
            break;
        }
    }
}

async fn bug_reader(
    idx: usize,
    mut reader: NetReader,
    in_tx: UnboundedSender<(Option<usize>, Message)>,
) {
    while let Ok(Some(message)) = read_message(&mut reader).await {
        let _ = in_tx.send((Some(idx), message));
    }
    let _ = in_tx.send((Some(idx), Message::Bye));
}

/// Join a Bughouse host at `addr`; mirror its broadcasts as NetEvents.
pub fn net_join_bughouse(
    addr: String,
    profile: PlayerProfileWire,
    sink: StreamSink<NetEvent>,
) -> Result<(), String> {
    let epoch = begin_session();
    runtime().block_on(async move {
        if let Err(e) = bug_join_task(addr, profile, &sink, epoch).await {
            if session_current(epoch) {
                let mut ev = NetEvent::of(NetEventKind::Error);
                ev.text = e;
                let _ = sink.add(ev);
            }
        }
        if session_current(epoch) {
            let _ = sink.add(NetEvent::of(NetEventKind::Disconnected));
        }
    });
    Ok(())
}

async fn bug_join_task(
    addr: String,
    wire_profile: PlayerProfileWire,
    sink: &StreamSink<NetEvent>,
    session_epoch: u64,
) -> Result<(), String> {
    if !session_current(session_epoch) {
        return Ok(());
    }
    let profile = wire_profile.to_protocol()?;
    let Some(stream) = join_connect(&addr, session_epoch).await? else {
        return Ok(());
    };
    let (rd, mut wr) = stream.into_split();
    let mut reader = BufReader::new(rd);

    if !join_write(
        &mut wr,
        Message::Hello {
            profile,
            protocol_version: PROTOCOL_VERSION,
            role: SessionRole::Player,
            base_minutes: 0,
            increment_seconds: 0,
        },
        session_epoch,
    )
    .await?
    {
        return Ok(());
    }

    let (otx, orx) = tokio::sync::mpsc::unbounded_channel::<Message>();
    let gen = SESSION_GEN.fetch_add(1, Ordering::Relaxed) + 1;
    *lock(bug_client_out()) = Some((gen, otx.clone()));
    tokio::spawn(bug_writer(wr, orx));
    let mut cancel_poll = tokio::time::interval(Duration::from_millis(100));
    cancel_poll.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    loop {
        if !session_current(session_epoch) {
            break;
        }
        tokio::select! {
            message = read_message(&mut reader) => match message {
                Ok(Some(message)) => {
                    if !bug_client_handle(message, sink) { break; }
                }
                _ => {
                    let mut ev = NetEvent::of(NetEventKind::Disconnected);
                    ev.text = "connection closed".into();
                    let _ = sink.add(ev);
                    break;
                }
            },
            _ = cancel_poll.tick() => {}
            _ = session_cancel().notified() => {
                if !session_current(session_epoch) {
                    break;
                }
            }
        }
    }

    let mut slot = lock(bug_client_out());
    if matches!(*slot, Some((g, _)) if g == gen) {
        *slot = None;
    }
    Ok(())
}

/// Surface one host broadcast as a NetEvent. Returns false to stop the loop.
fn bug_client_handle(message: Message, sink: &StreamSink<NetEvent>) -> bool {
    match message {
        Message::BugStart {
            seats,
            your_seats,
            base_minutes,
            increment_seconds,
        } => {
            let mut ev = NetEvent::of(NetEventKind::BugStart);
            ev.seats = seats
                .iter()
                .map(|profile| profile.username.clone())
                .collect();
            ev.seat_profiles = seats
                .iter()
                .filter_map(|profile| PlayerProfileWire::from_protocol(profile).ok())
                .collect();
            ev.your_seats = your_seats.iter().map(|&x| x as u32).collect();
            ev.base_minutes = base_minutes;
            ev.increment_seconds = increment_seconds;
            let _ = sink.add(ev);
        }
        Message::BugMove {
            board,
            uci,
            white_ms,
            black_ms,
        } => {
            let mut ev = NetEvent::of(NetEventKind::BugMove);
            ev.board = board as u32;
            ev.uci = uci;
            ev.white_ms = white_ms;
            ev.black_ms = black_ms;
            let _ = sink.add(ev);
        }
        Message::BugPass {
            to_board,
            to_color,
            piece,
        } => {
            let mut ev = NetEvent::of(NetEventKind::BugPass);
            ev.to_board = to_board as u32;
            ev.to_color = to_color as u32;
            ev.piece = piece as u32;
            let _ = sink.add(ev);
        }
        Message::BugResult {
            winning_team,
            board,
            ..
        } => {
            let mut ev = NetEvent::of(NetEventKind::BugResult);
            ev.winning_team = winning_team as u32;
            ev.board = board as u32;
            let _ = sink.add(ev);
        }
        Message::Bye => {
            let mut ev = NetEvent::of(NetEventKind::Disconnected);
            ev.text = "host left".into();
            let _ = sink.add(ev);
            return false;
        }
        Message::Reject { reason } => {
            let mut ev = NetEvent::of(NetEventKind::Error);
            ev.text = reason;
            let _ = sink.add(ev);
            return false;
        }
        _ => {}
    }
    true
}

fn bug_cmd(msg: Message) {
    if let Some((_, tx)) = lock(bug_inbound()).as_ref() {
        let _ = tx.send((None, msg)); // host: into the local authority
    } else if let Some((_, tx)) = lock(bug_client_out()).as_ref() {
        let _ = tx.send(msg); // client: over TCP to the host
    }
}

/// Host assigns the four seats and starts the match. `seat_owner[seat]` is the
/// connection index (join order, 0-based) or -1 for the host.
#[frb(sync)]
pub fn net_bug_start(seat_owner: Vec<i32>) {
    *lock(&BUG_ASSIGN) = Some(seat_owner);
    bug_assign_notify().notify_one();
}

#[frb(sync)]
pub fn net_send_bug_move(board: u32, uci: String, white_ms: i64, black_ms: i64) {
    bug_cmd(Message::BugMove {
        board: board as u8,
        uci,
        white_ms,
        black_ms,
    });
}

#[frb(sync)]
pub fn net_bug_resign(seat: u32) {
    bug_cmd(Message::BugResign { seat: seat as u8 });
}

// ===== 4-player chess: host-authoritative star (one cross board, 4 seats) =====
// Seats: 0=Red, 1=Blue, 2=Yellow, 3=Green. Untimed (chess4 has no clock).

/// Seat assignment sent by the Four-player LAN host UI. A player owns exactly
/// one seat; every remaining colour is played by the host-authoritative bot.
const FOUR_HOST_OWNER: i32 = -1;
const FOUR_AI_OWNER: i32 = -2;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum FourSeatOwner {
    Host,
    Peer(usize),
    Ai,
}

fn valid_four_seat_owners(seat_owner: &[i32], peer_count: usize) -> bool {
    if seat_owner.len() != 4 || peer_count > 3 {
        return false;
    }

    // Index zero is the host; each connected peer follows in join order. Every
    // human must be assigned exactly one colour, while any number of remaining
    // colours may be host-run AI.
    let mut assigned = vec![0_u8; peer_count + 1];
    for &owner in seat_owner {
        match owner {
            FOUR_AI_OWNER => {}
            FOUR_HOST_OWNER => assigned[0] = assigned[0].saturating_add(1),
            0.. => {
                let index = owner as usize;
                if index >= peer_count {
                    return false;
                }
                assigned[index + 1] = assigned[index + 1].saturating_add(1);
            }
            _ => return false,
        }
    }
    assigned.into_iter().all(|count| count == 1)
}

/// Decode the host-selected difficulty for each AI colour. The vector is
/// parallel to the four seat colours: `0..=5` means an AI difficulty and `-1`
/// means the colour is human-owned. Requiring an explicit `-1` for humans
/// prevents a crafted start command from silently applying a stale AI setting.
fn four_ai_difficulties(
    seat_owner: &[i32],
    difficulty_codes: &[i32],
) -> Option<[chess4::bot::BotDifficulty; 4]> {
    if seat_owner.len() != 4 || difficulty_codes.len() != 4 {
        return None;
    }
    let mut difficulties = [chess4::bot::BotDifficulty::Normal; 4];
    for seat in 0..4 {
        match seat_owner[seat] {
            FOUR_AI_OWNER => {
                difficulties[seat] = chess4::bot::BotDifficulty::from_code(difficulty_codes[seat])?;
            }
            FOUR_HOST_OWNER | 0.. => {
                if difficulty_codes[seat] != -1 {
                    return None;
                }
            }
            _ => return None,
        }
    }
    Some(difficulties)
}

fn four_owner_from_assignment(owner: i32) -> FourSeatOwner {
    match owner {
        FOUR_HOST_OWNER => FourSeatOwner::Host,
        FOUR_AI_OWNER => FourSeatOwner::Ai,
        peer if peer >= 0 => FourSeatOwner::Peer(peer as usize),
        _ => unreachable!("Four seat assignment must be validated before use"),
    }
}

fn four_owner_can_act(owner: FourSeatOwner, from: Option<usize>) -> bool {
    match (from, owner) {
        (None, FourSeatOwner::Host) => true,
        (Some(connection), FourSeatOwner::Peer(owner)) => connection == owner,
        _ => false,
    }
}

/// Authoritative source of a four-player message. Spectators need a distinct
/// source so a closed watcher cannot be mistaken for a player resignation.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum FourSource {
    Host,
    Peer(usize),
    Spectator(u64),
}

type FourInbound = Mutex<Option<(u64, UnboundedSender<(FourSource, Message)>)>>;
fn four_inbound() -> &'static FourInbound {
    static S: OnceLock<FourInbound> = OnceLock::new();
    S.get_or_init(|| Mutex::new(None))
}
/// The role gates bridge commands before they reach the socket. In particular,
/// a spectator must never be able to send a FourMove/FourResign command.
type FourClientOut = Mutex<Option<(u64, UnboundedSender<Message>, SessionRole)>>;
fn four_client_out() -> &'static FourClientOut {
    static S: OnceLock<FourClientOut> = OnceLock::new();
    S.get_or_init(|| Mutex::new(None))
}
struct FourStartAssignment {
    seat_owner: Vec<i32>,
    ai_difficulties: Vec<i32>,
}

static FOUR_ASSIGN: Mutex<Option<FourStartAssignment>> = Mutex::new(None);
fn four_assign_notify() -> &'static tokio::sync::Notify {
    static N: OnceLock<tokio::sync::Notify> = OnceLock::new();
    N.get_or_init(tokio::sync::Notify::new)
}

fn four_format(code: &str) -> chess4::Format {
    if code == "teams" {
        chess4::Format::Teams
    } else {
        chess4::Format::FreeForAll
    }
}

fn four_player_code(p: chess4::Player) -> &'static str {
    match p {
        chess4::Player::Red => "red",
        chess4::Player::Blue => "blue",
        chess4::Player::Yellow => "yellow",
        chess4::Player::Green => "green",
    }
}

fn four_result_str(r: chess4::FourResult) -> String {
    match r {
        chess4::FourResult::InProgress => "ongoing".into(),
        chess4::FourResult::TeamWin(chess4::Team::RedYellow) => "team:red_yellow".into(),
        chess4::FourResult::TeamWin(chess4::Team::BlueGreen) => "team:blue_green".into(),
        chess4::FourResult::FfaWin(p) => format!("ffa:{}", four_player_code(p)),
    }
}

fn four_apply_uci(game: &mut chess4::FourGame, uci: &str) -> bool {
    let Some((f, t, promo)) = chess4::serial::parse_uci(uci) else {
        return false;
    };
    let chosen = game
        .legal_moves()
        .into_iter()
        .find(|m| m.from == f && m.to == t && m.promo == promo);
    if let Some(m) = chosen {
        game.make_move(m);
        true
    } else {
        false
    }
}

/// One late spectator receives this many individually framed move messages at
/// most. Keeping a finite replay avoids retaining unbounded host memory while
/// still covering practical four-player games.
const MAX_FOUR_SPECTATOR_HISTORY: usize = 4_096;

/// Host a 4-player match: advertise "[4P]", accept ≤3 joiners, run the authority.
pub fn net_host_four(
    profile: PlayerProfileWire,
    format: String,
    allow_spectators: bool,
    sink: StreamSink<NetEvent>,
) -> Result<(), String> {
    let epoch = begin_session();
    runtime().block_on(async move {
        if let Err(e) = four_host_task(profile, format, allow_spectators, &sink, epoch).await {
            let mut ev = NetEvent::of(NetEventKind::Error);
            ev.text = e;
            let _ = sink.add(ev);
        }
        let _ = sink.add(NetEvent::of(NetEventKind::Disconnected));
    });
    Ok(())
}

async fn four_host_task(
    host_wire: PlayerProfileWire,
    format: String,
    allow_spectators: bool,
    sink: &StreamSink<NetEvent>,
    session_epoch: u64,
) -> Result<(), String> {
    if !session_current(session_epoch) {
        return Ok(());
    }
    let host_profile = host_wire.to_protocol()?;
    let ai_profile = ProtocolProfile::from_avatar_bytes("AI".into(), &[])
        .map_err(|reason| format!("invalid built-in four-player AI profile: {reason}"))?;
    let listener = bind_lan_listener().await?;
    let port = listener.local_addr().map_err(es)?.port();
    let mut advertiser = Some(
        chess_net::advertise(
            HostAdvertisement {
                name: host_profile.username.clone(),
                mode: "four_player".into(),
                variant: format.clone(),
                base_minutes: 0,
                increment_seconds: 0,
                // Spectators are exposed only after the host starts the live
                // match. Until then this remains a normal joinable lobby.
                allow_spectators: false,
                player_count: 1,
                max_players: 4,
            },
            port,
        )
        .map_err(|e| e.to_string())?,
    );

    let (in_tx, mut in_rx) = tokio::sync::mpsc::unbounded_channel::<(FourSource, Message)>();
    let (handshake_tx, mut handshake_rx) = tokio::sync::mpsc::unbounded_channel::<HostHandshake>();
    let gen = SESSION_GEN.fetch_add(1, Ordering::Relaxed) + 1;
    *lock(four_inbound()) = Some((gen, in_tx.clone()));

    let mut peers: Vec<BugPeer> = Vec::new();
    let mut spectators: Vec<HostPeer> = Vec::new();
    let mut next_spectator_id = 1_u64;
    let mut game = chess4::FourGame::new(four_format(&format));
    let mut seat_owner = [FourSeatOwner::Ai; 4];
    let mut ai_difficulties = [chess4::bot::BotDifficulty::Normal; 4];
    let mut seat_profiles: Option<Vec<ProtocolProfile>> = None;
    // `None` means the history exceeded the bounded catch-up limit. Existing
    // spectators continue normally, but a later connection gets a clear
    // rejection instead of a partial and therefore incorrect board.
    let mut history: Option<Vec<(u8, String)>> = Some(Vec::new());
    let mut started = false;
    let mut ended = false;
    let mut ai_seed = session_epoch;
    let mut pending_handshakes = 0_usize;
    let mut cancel_poll = tokio::time::interval(Duration::from_millis(100));
    cancel_poll.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    let mut ai_tick = tokio::time::interval(Duration::from_millis(300));
    ai_tick.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    loop {
        if !session_current(session_epoch) {
            break;
        }
        tokio::select! {
            r = listener.accept() => {
                let stream = match r { Ok((s, _)) => s, Err(_) => continue };
                if pending_handshakes >= MAX_PENDING_HOST_HANDSHAKES {
                    let (_, writer) = stream.into_split();
                    reject_host_handshake(writer, "host is busy; try again shortly".into());
                    continue;
                }
                pending_handshakes += 1;
                let tx = handshake_tx.clone();
                tokio::spawn(async move {
                    prepare_host_handshake(stream, tx).await;
                });
            }
            handshake = handshake_rx.recv() => {
                let Some(handshake) = handshake else { break };
                match handshake {
                    HostHandshake::Finished => {
                        pending_handshakes = pending_handshakes.saturating_sub(1);
                    }
                    HostHandshake::Ready { profile: peer_profile, role, reader, writer: wr } => {
                        match role {
                            SessionRole::Player => {
                                if started {
                                    reject_host_handshake(wr, "the four-player match has already started".into());
                                    continue;
                                }
                                if peers.len() >= 3 {
                                    reject_host_handshake(wr, "four-player lobby is full".into());
                                    continue;
                                }
                                let idx = peers.len();
                                let (ptx, prx) = tokio::sync::mpsc::unbounded_channel::<Message>();
                                tokio::spawn(bug_writer(wr, prx));
                                tokio::spawn(four_reader(FourSource::Peer(idx), reader, in_tx.clone()));
                                peers.push((ptx, peer_profile.clone()));
                                if let Some(advertiser) = advertiser.as_mut() {
                                    let _ = advertiser.update_player_count(1 + peers.len() as u32);
                                }
                                let mut ev = NetEvent::of(NetEventKind::FourJoin);
                                ev.text = peer_profile.username.clone();
                                ev.peer_profile = PlayerProfileWire::from_protocol(&peer_profile)?;
                                ev.seat = idx as u32;
                                let _ = sink.add(ev);
                            }
                            SessionRole::Spectator => {
                                if !allow_spectators {
                                    reject_host_handshake(wr, "spectators are disabled by this host".into());
                                    continue;
                                }
                                if !started {
                                    reject_host_handshake(wr, "the match is not live yet".into());
                                    continue;
                                }
                                if ended {
                                    reject_host_handshake(wr, "the match has already ended".into());
                                    continue;
                                }
                                let Some(active_seats) = seat_profiles.as_ref() else {
                                    reject_host_handshake(wr, "the match state is not ready".into());
                                    continue;
                                };
                                let Some(replay) = history.as_ref() else {
                                    reject_host_handshake(
                                        wr,
                                        "this match is too long to synchronize a new spectator".into(),
                                    );
                                    continue;
                                };
                                let id = next_spectator_id;
                                next_spectator_id = next_spectator_id.saturating_add(1);
                                let (ptx, prx) = tokio::sync::mpsc::unbounded_channel::<Message>();
                                tokio::spawn(bug_writer(wr, prx));
                                let spectator = HostPeer {
                                    id,
                                    tx: ptx,
                                    username: peer_profile.username.clone(),
                                };
                                if spectator.tx.send(Message::FourStart {
                                    format: format.clone(),
                                    seats: active_seats.clone(),
                                    your_seats: Vec::new(),
                                }).is_err() {
                                    continue;
                                }
                                let mut replayed = true;
                                for (seat, uci) in replay {
                                    if spectator.tx.send(Message::FourMove {
                                        seat: *seat,
                                        uci: uci.clone(),
                                    }).is_err() {
                                        replayed = false;
                                        break;
                                    }
                                }
                                if !replayed {
                                    continue;
                                }
                                tokio::spawn(four_reader(
                                    FourSource::Spectator(id),
                                    reader,
                                    in_tx.clone(),
                                ));
                                spectators.push(spectator);
                                let mut ev = NetEvent::of(NetEventKind::SpectatorJoined);
                                ev.peer_profile = PlayerProfileWire::from_protocol(&peer_profile)?;
                                ev.text = peer_profile.username;
                                let _ = sink.add(ev);
                            }
                        }
                    }
                }
            }
            _ = four_assign_notify().notified(), if !started => {
                let Some(FourStartAssignment { seat_owner: owner, ai_difficulties: difficulty_codes }) = lock(&FOUR_ASSIGN).take() else {
                    continue;
                };
                if !valid_four_seat_owners(&owner, peers.len()) {
                    let mut event = NetEvent::of(NetEventKind::Error);
                    event.text = "invalid four-player seat assignment".into();
                    let _ = sink.add(event);
                    continue;
                }
                let Some(selected_difficulties) = four_ai_difficulties(&owner, &difficulty_codes) else {
                    let mut event = NetEvent::of(NetEventKind::Error);
                    event.text = "invalid four-player AI difficulty assignment".into();
                    let _ = sink.add(event);
                    continue;
                };
                for (seat, owner_index) in owner.iter().enumerate() {
                    seat_owner[seat] = four_owner_from_assignment(*owner_index);
                }
                ai_difficulties = selected_difficulties;
                let assigned_profiles: Vec<ProtocolProfile> = (0..4)
                    .map(|s| match seat_owner[s] {
                        FourSeatOwner::Host => host_profile.clone(),
                        FourSeatOwner::Peer(i) => peers
                            .get(i)
                            .map(|peer| peer.1.clone())
                            .unwrap_or_else(|| host_profile.clone()),
                        FourSeatOwner::Ai => ai_profile.clone(),
                    })
                    .collect();
                let names: Vec<String> = assigned_profiles
                    .iter()
                    .map(|profile| profile.username.clone())
                    .collect();
                for (i, (tx, _)) in peers.iter().enumerate() {
                    let my: Vec<u8> =
                        (0..4u8)
                            .filter(|&s| seat_owner[s as usize] == FourSeatOwner::Peer(i))
                            .collect();
                    let _ = tx.send(Message::FourStart {
                        format: format.clone(),
                        seats: assigned_profiles.clone(),
                        your_seats: my,
                    });
                }
                let host_seats: Vec<u32> =
                    (0..4u32)
                        .filter(|&s| seat_owner[s as usize] == FourSeatOwner::Host)
                        .collect();
                let mut ev = NetEvent::of(NetEventKind::FourStart);
                ev.your_seats = host_seats;
                ev.seats = names;
                ev.seat_profiles = assigned_profiles
                    .iter()
                    .map(PlayerProfileWire::from_protocol)
                    .collect::<Result<Vec<_>, _>>()?;
                ev.variant = format.clone(); // reuse `variant` to carry the format code
                let _ = sink.add(ev);
                started = true;
                seat_profiles = Some(assigned_profiles);
                if allow_spectators {
                    // The match is no longer joinable, but discovery keeps the
                    // live spectator action visible.
                    if let Some(advertiser) = advertiser.as_mut() {
                        let _ = advertiser.update_availability(4, true);
                    }
                } else {
                    drop(advertiser.take());
                }
            }
            msg = in_rx.recv() => {
                let Some((from, m)) = msg else { break };
                if !started && matches!(from, FourSource::Peer(_)) && matches!(&m, Message::Bye) {
                    let mut event = NetEvent::of(NetEventKind::Error);
                    event.text = "a lobby player disconnected; host a new match".into();
                    let _ = sink.add(event);
                    break;
                }
                match from {
                    FourSource::Spectator(id) => {
                        four_spectator_message(id, m, &mut spectators);
                    }
                    FourSource::Host if started && !ended => {
                        four_authority(
                            None,
                            m,
                            &mut game,
                            &seat_owner,
                            &peers,
                            &spectators,
                            sink,
                            &mut ended,
                            &mut history,
                        );
                    }
                    FourSource::Peer(peer) if started && !ended => {
                        four_authority(
                            Some(peer),
                            m,
                            &mut game,
                            &seat_owner,
                            &peers,
                            &spectators,
                            sink,
                            &mut ended,
                            &mut history,
                        );
                    }
                    _ => {}
                }
                if ended {
                    // A completed match cannot be reconstructed by a new
                    // spectator, so stop advertising it immediately.
                    drop(advertiser.take());
                }
            }
            _ = ai_tick.tick(), if started && !ended && seat_owner[game.turn.index()] == FourSeatOwner::Ai => {
                ai_seed = ai_seed.wrapping_add(1);
                let difficulty = ai_difficulties[game.turn.index()];
                four_play_ai_turn(
                    &mut game,
                    &peers,
                    &spectators,
                    sink,
                    &mut ended,
                    &mut history,
                    difficulty,
                    ai_seed,
                );
                if ended {
                    drop(advertiser.take());
                }
            }
            _ = cancel_poll.tick() => {}
            _ = session_cancel().notified() => {
                if !session_current(session_epoch) {
                    break;
                }
            }
        }
    }

    bug_broadcast(&peers, &Message::Bye);
    broadcast(&spectators, &Message::Bye);
    let mut slot = lock(four_inbound());
    if matches!(*slot, Some((g, _)) if g == gen) {
        *slot = None;
    }
    Ok(())
}

async fn four_reader(
    source: FourSource,
    mut reader: NetReader,
    tx: UnboundedSender<(FourSource, Message)>,
) {
    while let Ok(Some(message)) = read_message(&mut reader).await {
        if tx.send((source, message)).is_err() {
            return;
        }
    }
    // A player closing its socket is still a forfeit. A watcher closing its
    // socket is handled separately and only removes that watcher.
    let _ = tx.send((source, Message::Bye));
}

/// Handle traffic that can originate from a four-player spectator. The host
/// never forwards this channel to players, and all board commands are rejected
/// before they reach the game authority.
fn four_spectator_message(id: u64, message: Message, spectators: &mut Vec<HostPeer>) {
    match message {
        Message::Bye => {
            spectators.retain(|spectator| spectator.id != id);
        }
        Message::SpectatorChat { text } => {
            let text = text.trim();
            if text.is_empty() || text.len() > MAX_CHAT_BYTES {
                if let Some(spectator) = spectators.iter().find(|spectator| spectator.id == id) {
                    let _ = spectator.tx.send(Message::Reject {
                        reason: "spectator chat message exceeds the LAN limit".into(),
                    });
                }
                return;
            }
            let Some(sender) = spectators
                .iter()
                .find(|spectator| spectator.id == id)
                .map(|spectator| spectator.username.clone())
            else {
                return;
            };
            // The sender renders its local bubble optimistically. Do not echo
            // it back, and never expose it to a player transport.
            broadcast_except(
                spectators,
                id,
                &Message::SpectatorChatBroadcast {
                    sender,
                    text: text.to_owned(),
                },
            );
        }
        Message::Ping { t } => {
            if let Some(spectator) = spectators.iter().find(|spectator| spectator.id == id) {
                let _ = spectator.tx.send(Message::Pong { t });
            }
        }
        Message::Pong { .. } => {}
        _ => {
            if let Some(spectator) = spectators.iter().find(|spectator| spectator.id == id) {
                let _ = spectator.tx.send(Message::Reject {
                    reason: "spectators are read-only".into(),
                });
            }
        }
    }
}

#[allow(clippy::too_many_arguments)]
fn four_authority(
    from: Option<usize>,
    m: Message,
    game: &mut chess4::FourGame,
    seat_owner: &[FourSeatOwner; 4],
    peers: &[BugPeer],
    spectators: &[HostPeer],
    sink: &StreamSink<NetEvent>,
    ended: &mut bool,
    history: &mut Option<Vec<(u8, String)>>,
) {
    match m {
        Message::FourMove { seat, uci } => {
            if seat >= 4 || seat as usize != game.turn.index() {
                return; // not the seat to move
            }
            let owner = seat_owner[seat as usize];
            if !four_owner_can_act(owner, from) {
                return;
            }
            if !four_apply_uci(game, &uci) {
                return;
            }
            four_publish_move(game, seat, uci, peers, spectators, sink, ended, history);
        }
        Message::FourResign { seat } => {
            if seat >= 4 {
                return;
            }
            let owner = seat_owner[seat as usize];
            if four_owner_can_act(owner, from) {
                four_finish("forfeit".into(), peers, spectators, sink, ended);
            }
        }
        Message::Bye => {
            // A connected participant may only forfeit its assigned human seat.
            // Host-run AI seats never grant a remote action permission.
            let allowed = match from {
                Some(peer) => seat_owner.contains(&FourSeatOwner::Peer(peer)),
                None => seat_owner.contains(&FourSeatOwner::Host),
            };
            if allowed {
                four_finish("forfeit".into(), peers, spectators, sink, ended);
            }
        }
        _ => {}
    }
}

#[allow(clippy::too_many_arguments)]
fn four_publish_move(
    game: &chess4::FourGame,
    seat: u8,
    uci: String,
    peers: &[BugPeer],
    spectators: &[HostPeer],
    sink: &StreamSink<NetEvent>,
    ended: &mut bool,
    history: &mut Option<Vec<(u8, String)>>,
) {
    record_four_history(history, seat, &uci);
    let outbound = Message::FourMove {
        seat,
        uci: uci.clone(),
    };
    bug_broadcast(peers, &outbound);
    broadcast(spectators, &outbound);
    let mut ev = NetEvent::of(NetEventKind::FourMove);
    ev.seat = seat as u32;
    ev.uci = uci;
    let _ = sink.add(ev);
    if game.ended {
        four_finish(
            four_result_str(game.result()),
            peers,
            spectators,
            sink,
            ended,
        );
    }
}

fn record_four_history(history: &mut Option<Vec<(u8, String)>>, seat: u8, uci: &str) {
    if history
        .as_ref()
        .is_some_and(|moves| moves.len() >= MAX_FOUR_SPECTATOR_HISTORY)
    {
        *history = None;
    } else if let Some(history) = history {
        history.push((seat, uci.to_owned()));
    }
}

#[allow(clippy::too_many_arguments)]
fn four_play_ai_turn(
    game: &mut chess4::FourGame,
    peers: &[BugPeer],
    spectators: &[HostPeer],
    sink: &StreamSink<NetEvent>,
    ended: &mut bool,
    history: &mut Option<Vec<(u8, String)>>,
    difficulty: chess4::bot::BotDifficulty,
    seed: u64,
) {
    let seat = game.turn.index() as u8;
    let Some(mv) = chess4::bot::move_for_difficulty(game, difficulty, seed) else {
        let mut event = NetEvent::of(NetEventKind::Error);
        event.text = "four-player AI has no legal move".into();
        let _ = sink.add(event);
        four_finish("forfeit".into(), peers, spectators, sink, ended);
        return;
    };
    let uci = chess4::serial::move_to_uci(mv);
    if !game.make_move(mv) {
        let mut event = NetEvent::of(NetEventKind::Error);
        event.text = "four-player AI generated an invalid move".into();
        let _ = sink.add(event);
        four_finish("forfeit".into(), peers, spectators, sink, ended);
        return;
    }
    four_publish_move(game, seat, uci, peers, spectators, sink, ended, history);
}

fn four_finish(
    result: String,
    peers: &[BugPeer],
    spectators: &[HostPeer],
    sink: &StreamSink<NetEvent>,
    ended: &mut bool,
) {
    if *ended {
        return;
    }
    *ended = true;
    let outbound = Message::FourResult {
        result: result.clone(),
    };
    bug_broadcast(peers, &outbound);
    broadcast(spectators, &outbound);
    let mut ev = NetEvent::of(NetEventKind::FourResult);
    ev.text = result;
    let _ = sink.add(ev);
}

pub fn net_join_four(
    addr: String,
    profile: PlayerProfileWire,
    sink: StreamSink<NetEvent>,
) -> Result<(), String> {
    let epoch = begin_session();
    runtime().block_on(async move {
        if let Err(e) = four_join_task(addr, profile, SessionRole::Player, &sink, epoch).await {
            if session_current(epoch) {
                let mut ev = NetEvent::of(NetEventKind::Error);
                ev.text = e;
                let _ = sink.add(ev);
            }
        }
        if session_current(epoch) {
            let _ = sink.add(NetEvent::of(NetEventKind::Disconnected));
        }
    });
    Ok(())
}

/// Join an enabled live four-player host as a strictly read-only spectator.
pub fn net_spectate_four(
    addr: String,
    profile: PlayerProfileWire,
    sink: StreamSink<NetEvent>,
) -> Result<(), String> {
    let epoch = begin_session();
    runtime().block_on(async move {
        if let Err(e) = four_join_task(addr, profile, SessionRole::Spectator, &sink, epoch).await {
            if session_current(epoch) {
                let mut ev = NetEvent::of(NetEventKind::Error);
                ev.text = e;
                let _ = sink.add(ev);
            }
        }
        if session_current(epoch) {
            let _ = sink.add(NetEvent::of(NetEventKind::Disconnected));
        }
    });
    Ok(())
}

async fn four_join_task(
    addr: String,
    wire_profile: PlayerProfileWire,
    requested_role: SessionRole,
    sink: &StreamSink<NetEvent>,
    session_epoch: u64,
) -> Result<(), String> {
    if !session_current(session_epoch) {
        return Ok(());
    }
    let profile = wire_profile.to_protocol()?;
    let Some(stream) = join_connect(&addr, session_epoch).await? else {
        return Ok(());
    };
    let (rd, mut wr) = stream.into_split();
    let mut reader = BufReader::new(rd);

    if !join_write(
        &mut wr,
        Message::Hello {
            profile,
            protocol_version: PROTOCOL_VERSION,
            role: requested_role,
            base_minutes: 0,
            increment_seconds: 0,
        },
        session_epoch,
    )
    .await?
    {
        return Ok(());
    }

    let (otx, orx) = tokio::sync::mpsc::unbounded_channel::<Message>();
    let gen = SESSION_GEN.fetch_add(1, Ordering::Relaxed) + 1;
    *lock(four_client_out()) = Some((gen, otx.clone(), requested_role));
    tokio::spawn(bug_writer(wr, orx));
    let mut cancel_poll = tokio::time::interval(Duration::from_millis(100));
    cancel_poll.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

    loop {
        if !session_current(session_epoch) {
            break;
        }
        tokio::select! {
            message = read_message(&mut reader) => match message {
                Ok(Some(message)) => {
                    if !four_client_handle(
                        message,
                        sink,
                        requested_role == SessionRole::Spectator,
                        &otx,
                    ) {
                        break;
                    }
                }
                _ => {
                    let mut ev = NetEvent::of(NetEventKind::Disconnected);
                    ev.text = "connection closed".into();
                    let _ = sink.add(ev);
                    break;
                }
            },
            _ = cancel_poll.tick() => {}
            _ = session_cancel().notified() => {
                if !session_current(session_epoch) {
                    break;
                }
            }
        }
    }

    let mut slot = lock(four_client_out());
    if matches!(*slot, Some((g, _, _)) if g == gen) {
        *slot = None;
    }
    Ok(())
}

fn four_client_handle(
    message: Message,
    sink: &StreamSink<NetEvent>,
    is_spectator: bool,
    outgoing: &UnboundedSender<Message>,
) -> bool {
    match message {
        Message::FourStart {
            format,
            seats,
            your_seats,
        } => {
            if seats.len() != 4 || (is_spectator && !your_seats.is_empty()) {
                let mut ev = NetEvent::of(NetEventKind::Error);
                ev.text = "invalid four-player spectator start state".into();
                let _ = sink.add(ev);
                return false;
            }
            let seat_profiles = match seats
                .iter()
                .map(PlayerProfileWire::from_protocol)
                .collect::<Result<Vec<_>, _>>()
            {
                Ok(profiles) => profiles,
                Err(reason) => {
                    let mut ev = NetEvent::of(NetEventKind::Error);
                    ev.text = reason;
                    let _ = sink.add(ev);
                    return false;
                }
            };
            let mut ev = NetEvent::of(NetEventKind::FourStart);
            ev.variant = format;
            ev.seats = seats
                .iter()
                .map(|profile| profile.username.clone())
                .collect();
            ev.seat_profiles = seat_profiles;
            ev.your_seats = your_seats.iter().map(|&x| x as u32).collect();
            ev.is_spectator = is_spectator;
            let _ = sink.add(ev);
        }
        Message::FourMove { seat, uci } => {
            let mut ev = NetEvent::of(NetEventKind::FourMove);
            ev.seat = seat as u32;
            ev.uci = uci;
            let _ = sink.add(ev);
        }
        Message::FourResult { result } => {
            let mut ev = NetEvent::of(NetEventKind::FourResult);
            ev.text = result;
            let _ = sink.add(ev);
        }
        Message::SpectatorChatBroadcast { sender, text } => {
            if is_spectator
                && !text.trim().is_empty()
                && text.len() <= MAX_CHAT_BYTES
                && ProtocolProfile::from_avatar_bytes(sender.clone(), &[]).is_ok()
            {
                let mut ev = NetEvent::of(NetEventKind::SpectatorChat);
                ev.sender = sender;
                ev.text = text;
                let _ = sink.add(ev);
            }
        }
        Message::Ping { t } => {
            let _ = outgoing.send(Message::Pong { t });
        }
        Message::Pong { .. } | Message::SpectatorChat { .. } => {}
        Message::Bye => {
            let mut ev = NetEvent::of(NetEventKind::Disconnected);
            ev.text = "host left".into();
            let _ = sink.add(ev);
            return false;
        }
        Message::Reject { reason } => {
            let mut ev = NetEvent::of(NetEventKind::Error);
            ev.text = reason;
            let _ = sink.add(ev);
            return false;
        }
        _ => {}
    }
    true
}

fn four_cmd(msg: Message) {
    if let Some((_, tx)) = lock(four_inbound()).as_ref() {
        let _ = tx.send((FourSource::Host, msg));
    } else if let Some((_, tx, SessionRole::Player)) = lock(four_client_out()).as_ref() {
        let _ = tx.send(msg);
    }
}

/// Host assigns seats and starts the match. `seat_owner` values are `-1` for
/// the host, `0..=2` for joined peers in join order, and `-2` for host-run AI.
/// `ai_difficulties` is parallel to the four colours: `0=Very Easy`,
/// `1=Easy`, `2=Normal`, `3=Hard`, `4=Very Hard`, `5=Impossible`; every human
/// seat must use `-1`.
#[frb(sync)]
pub fn net_four_start(seat_owner: Vec<i32>, ai_difficulties: Vec<i32>) {
    *lock(&FOUR_ASSIGN) = Some(FourStartAssignment {
        seat_owner,
        ai_difficulties,
    });
    four_assign_notify().notify_one();
}

#[frb(sync)]
pub fn net_send_four_move(seat: u32, uci: String) {
    four_cmd(Message::FourMove {
        seat: seat as u8,
        uci,
    });
}

#[frb(sync)]
pub fn net_four_resign(seat: u32) {
    four_cmd(Message::FourResign { seat: seat as u8 });
}

#[cfg(test)]
mod tests {
    use chess4::{Format, FourGame, Player};
    use chess_net::{Message, PlayerProfile, SessionRole, PROTOCOL_VERSION};

    use super::{
        bind_lan_listener, broadcast_except, four_ai_difficulties, four_apply_uci,
        four_owner_can_act, four_spectator_message, record_four_history, valid_four_seat_owners,
        valid_network_seat_owners, validate_host_hello, FourSeatOwner, HostPeer, LAN_PORT_MAX,
        LAN_PORT_MIN, MAX_FOUR_SPECTATOR_HISTORY,
    };

    fn hello(protocol_version: u32) -> Message {
        Message::Hello {
            profile: PlayerProfile::from_avatar_bytes("player".into(), &[]).unwrap(),
            protocol_version,
            role: SessionRole::Player,
            base_minutes: 10,
            increment_seconds: 0,
        }
    }

    #[test]
    fn generic_host_handshake_validates_before_handoff() {
        assert!(validate_host_hello(hello(PROTOCOL_VERSION)).is_ok());
        assert_eq!(
            validate_host_hello(hello(PROTOCOL_VERSION + 1)).unwrap_err(),
            "incompatible protocol version"
        );
        assert_eq!(
            validate_host_hello(Message::Ping { t: 0 }).unwrap_err(),
            "expected hello"
        );
    }

    #[test]
    fn network_seats_require_four_distinct_devices() {
        assert!(valid_network_seat_owners(&[-1, 0, 1, 2], 3));
        assert!(!valid_network_seat_owners(&[-1, -1, 1, 2], 3));
        assert!(!valid_network_seat_owners(&[-1, 0, 1, 1], 3));
        assert!(!valid_network_seat_owners(&[-1, 0, 1, 2], 2));
        assert!(!valid_network_seat_owners(&[-1, 0, 1, 3], 3));
    }

    #[test]
    fn four_lan_seats_allow_host_run_ai_without_multi_seat_humans() {
        assert!(valid_four_seat_owners(&[-1, -2, -2, -2], 0));
        assert!(valid_four_seat_owners(&[-1, 0, -2, -2], 1));
        assert!(valid_four_seat_owners(&[-1, 0, 1, -2], 2));
        assert!(valid_four_seat_owners(&[-1, 0, 1, 2], 3));

        assert!(!valid_four_seat_owners(&[-1, -1, -2, -2], 0));
        assert!(!valid_four_seat_owners(&[-1, 0, 0, -2], 1));
        assert!(!valid_four_seat_owners(&[-1, 1, -2, -2], 1));
        assert!(!valid_four_seat_owners(&[-1, 0, -2, -2], 2));
    }

    #[test]
    fn four_lan_ai_difficulties_are_exact_and_ai_only() {
        let assignment = [-1, 0, -2, -2];
        let selected = four_ai_difficulties(&assignment, &[-1, -1, 0, 5]).unwrap();
        assert_eq!(selected[2].code(), 0);
        assert_eq!(selected[3].code(), 5);

        // A difficulty on a human colour, an omitted AI code, an unknown code,
        // or an incomplete vector must all fail before the match starts.
        assert!(four_ai_difficulties(&assignment, &[2, -1, 0, 5]).is_none());
        assert!(four_ai_difficulties(&assignment, &[-1, -1, -1, 5]).is_none());
        assert!(four_ai_difficulties(&assignment, &[-1, -1, 6, 5]).is_none());
        assert!(four_ai_difficulties(&assignment, &[-1, -1, 2]).is_none());
    }

    #[test]
    fn ai_seats_never_authorize_host_or_peer_commands() {
        assert!(four_owner_can_act(FourSeatOwner::Host, None));
        assert!(four_owner_can_act(FourSeatOwner::Peer(1), Some(1)));
        assert!(!four_owner_can_act(FourSeatOwner::Peer(1), Some(0)));
        assert!(!four_owner_can_act(FourSeatOwner::Ai, None));
        assert!(!four_owner_can_act(FourSeatOwner::Ai, Some(0)));
    }

    #[test]
    fn authority_applies_a_remote_blue_move_as_soon_as_red_has_moved() {
        // This is the host-side route used for a phone controlling Blue. It
        // must accept the message in the same authority cycle; no follow-up
        // Red command is required to make the Blue move visible.
        let mut game = FourGame::new(Format::FreeForAll);
        assert!(four_apply_uci(&mut game, "d2d3"));
        assert_eq!(game.turn, Player::Blue);

        assert!(four_apply_uci(&mut game, "b4c4"));
        assert_eq!(game.turn, Player::Yellow);
        assert_eq!(
            game.board.get(2, 3),
            Some((Player::Blue, chess4::Piece::Pawn))
        );
    }

    #[test]
    fn authority_preserves_blue_castling_when_parsing_coordinate_move() {
        let mut game = FourGame::new(Format::FreeForAll);
        game.turn = Player::Blue;
        game.board.clear(0, 8); // bishop
        game.board.clear(0, 9); // knight

        // Blue's king starts at a8 and castles toward the a11 rook by moving
        // to a10. `four_apply_uci` must retain the engine move's `castle`
        // flag instead of treating this as an ordinary king relocation.
        assert!(four_apply_uci(&mut game, "a8a10"));
        assert_eq!(
            game.board.get(0, 9),
            Some((Player::Blue, chess4::Piece::King))
        );
        assert_eq!(
            game.board.get(0, 8),
            Some((Player::Blue, chess4::Piece::Rook))
        );
    }

    #[test]
    fn spectator_chat_broadcast_excludes_its_source() {
        let (source_tx, mut source_rx) = tokio::sync::mpsc::unbounded_channel();
        let (other_tx, mut other_rx) = tokio::sync::mpsc::unbounded_channel();
        let spectators = vec![
            HostPeer {
                id: 1,
                tx: source_tx,
                username: "source".into(),
            },
            HostPeer {
                id: 2,
                tx: other_tx,
                username: "other".into(),
            },
        ];
        let message = Message::SpectatorChatBroadcast {
            sender: "source".into(),
            text: "hello".into(),
        };

        broadcast_except(&spectators, 1, &message);

        assert!(source_rx.try_recv().is_err());
        assert_eq!(other_rx.try_recv().unwrap(), message);
    }

    #[test]
    fn four_spectator_chat_is_private_and_watcher_close_only_removes_watcher() {
        let (source_tx, mut source_rx) = tokio::sync::mpsc::unbounded_channel();
        let (other_tx, mut other_rx) = tokio::sync::mpsc::unbounded_channel();
        let mut spectators = vec![
            HostPeer {
                id: 1,
                tx: source_tx,
                username: "source".into(),
            },
            HostPeer {
                id: 2,
                tx: other_tx,
                username: "other".into(),
            },
        ];

        four_spectator_message(
            1,
            Message::SpectatorChat {
                text: "private".into(),
            },
            &mut spectators,
        );
        assert!(source_rx.try_recv().is_err());
        assert_eq!(
            other_rx.try_recv().unwrap(),
            Message::SpectatorChatBroadcast {
                sender: "source".into(),
                text: "private".into(),
            }
        );

        four_spectator_message(
            1,
            Message::FourMove {
                seat: 0,
                uci: "d1d2".into(),
            },
            &mut spectators,
        );
        assert_eq!(
            source_rx.try_recv().unwrap(),
            Message::Reject {
                reason: "spectators are read-only".into(),
            }
        );

        four_spectator_message(1, Message::Bye, &mut spectators);
        assert_eq!(spectators.len(), 1);
        assert_eq!(spectators[0].id, 2);
    }

    #[test]
    fn four_spectator_replay_stays_complete_or_is_unavailable() {
        let mut history = Some(Vec::new());
        record_four_history(&mut history, 0, "d1d2");
        assert_eq!(history, Some(vec![(0, "d1d2".into())]));

        let mut full_history = Some(
            (0..MAX_FOUR_SPECTATOR_HISTORY)
                .map(|move_number| ((move_number % 4) as u8, "d1d2".into()))
                .collect(),
        );
        record_four_history(&mut full_history, 0, "d2d3");
        assert!(full_history.is_none());
    }

    #[tokio::test]
    async fn lan_listener_uses_the_documented_port_range() {
        let listener = bind_lan_listener().await.unwrap();
        let port = listener.local_addr().unwrap().port();
        assert!((LAN_PORT_MIN..=LAN_PORT_MAX).contains(&port));
    }
}

//! Newline-delimited JSON protocol for LAN play.

use base64::{engine::general_purpose::STANDARD as BASE64, Engine as _};
use serde::{Deserialize, Serialize};

/// Bumped on incompatible protocol changes; peers reject mismatches.
pub const PROTOCOL_VERSION: u32 = 7;

/// Profile limits are enforced on both sides of every handshake. The avatar
/// limit applies before Base64 expansion so a profile cannot dominate a LAN
/// session's JSON traffic.
/// Mirrors the UI's 24-code-point name limit while allowing four-byte UTF-8
/// characters such as CJK names.
pub const MAX_USERNAME_BYTES: usize = 96;
pub const MAX_USERNAME_CHARS: usize = 24;
// Four-seat start messages carry four profiles. Keep the pre-Base64 JPEG cap
// low enough that a full Bughouse/Four-player payload remains well below the
// bounded JSON-line limit even when every player has a custom avatar.
pub const MAX_AVATAR_BYTES: usize = 8 * 1024;
pub const MAX_MESSAGE_BYTES: usize = 64 * 1024;

/// mDNS service type advertised/browsed for Open Chess hosts.
pub const SERVICE_TYPE: &str = "_open-chess._tcp.local.";

/// Compact profile transported in protocol messages. Avatars are Base64 so
/// newline-delimited JSON remains portable across every supported platform.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub struct PlayerProfile {
    pub username: String,
    pub avatar_base64: String,
}

impl PlayerProfile {
    pub fn from_avatar_bytes(username: String, avatar_bytes: &[u8]) -> Result<Self, String> {
        validate_username(&username)?;
        validate_avatar(avatar_bytes)?;
        Ok(Self {
            username,
            avatar_base64: BASE64.encode(avatar_bytes),
        })
    }

    pub fn avatar_bytes(&self) -> Result<Vec<u8>, String> {
        self.validate()?;
        BASE64
            .decode(&self.avatar_base64)
            .map_err(|_| "avatar is not valid Base64".to_string())
    }

    pub fn validate(&self) -> Result<(), String> {
        validate_username(&self.username)?;
        let avatar = BASE64
            .decode(&self.avatar_base64)
            .map_err(|_| "avatar is not valid Base64".to_string())?;
        validate_avatar(&avatar)?;
        Ok(())
    }
}

fn validate_username(username: &str) -> Result<(), String> {
    if username.trim().is_empty() {
        return Err("username must not be empty".to_string());
    }
    if username.len() > MAX_USERNAME_BYTES {
        return Err(format!(
            "username exceeds {MAX_USERNAME_BYTES} byte LAN limit"
        ));
    }
    if username.chars().count() > MAX_USERNAME_CHARS {
        return Err(format!(
            "username exceeds {MAX_USERNAME_CHARS} character LAN limit"
        ));
    }
    if username.chars().any(char::is_control) {
        return Err("username contains a control character".to_string());
    }
    Ok(())
}

fn validate_avatar(avatar: &[u8]) -> Result<(), String> {
    if avatar.len() > MAX_AVATAR_BYTES {
        return Err(format!("avatar exceeds {MAX_AVATAR_BYTES} byte LAN limit"));
    }
    if avatar.is_empty() {
        return Ok(()); // built-in pawn avatar
    }
    if avatar.len() < 4 || !avatar.starts_with(&[0xff, 0xd8]) || !avatar.ends_with(&[0xff, 0xd9]) {
        return Err("avatar must be a JPEG payload".to_string());
    }
    Ok(())
}

/// A player can act; a spectator may receive state only.
#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum SessionRole {
    Player,
    Spectator,
}

/// Variant state not represented by FEN. This accompanies a live spectator
/// snapshot so Three-check and Crazyhouse continue with exactly the same legal
/// position as the host.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub struct VariantState {
    pub white_checks: u8,
    pub black_checks: u8,
    /// Reserve counts in Pawn, Knight, Bishop, Rook, Queen order.
    pub white_hand: [u8; 5],
    pub black_hand: [u8; 5],
    /// Crazyhouse promoted-pawn square mask.
    pub promoted: u64,
}

impl VariantState {
    pub const EMPTY: Self = Self {
        white_checks: 0,
        black_checks: 0,
        white_hand: [0; 5],
        black_hand: [0; 5],
        promoted: 0,
    };

    pub fn validate(&self) -> Result<(), String> {
        if self.white_checks > 3 || self.black_checks > 3 {
            return Err("three-check counter exceeds 3".to_string());
        }
        // No reserve can contain more than every non-king piece on the board.
        if self
            .white_hand
            .iter()
            .chain(self.black_hand.iter())
            .any(|&count| count > 30)
        {
            return Err("reserve count exceeds LAN limit".to_string());
        }
        Ok(())
    }
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Message {
    /// First message from the joiner: identity + proposed time control.
    Hello {
        profile: PlayerProfile,
        protocol_version: u32,
        role: SessionRole,
        base_minutes: u32,
        increment_seconds: u32,
    },
    /// Host arbitrates and replies with agreed parameters + colors. `variant`
    /// is the variant code (e.g. "standard", "crazyhouse"); `fen` carries the
    /// concrete start position (e.g. the Chess960 layout).
    Start {
        white_profile: PlayerProfile,
        black_profile: PlayerProfile,
        you_are_white: bool,
        role: SessionRole,
        base_minutes: u32,
        increment_seconds: u32,
        fen: String,
        variant: String,
        white_ms: i64,
        black_ms: i64,
        variant_state: VariantState,
    },
    /// A host rejects a handshake or a forbidden action without treating it as
    /// a normal game result.
    Reject {
        reason: String,
    },
    /// Host → player when an enabled spectator enters. It is informational and
    /// carries no permission to act.
    SpectatorJoined {
        profile: PlayerProfile,
    },
    /// A move plus the ply and both clocks (for drift reconciliation).
    Move {
        uci: String,
        ply: u32,
        white_ms: i64,
        black_ms: i64,
    },
    /// Host-authoritative flag fall. `loser_white` identifies the side whose
    /// clock reached zero; clients render a time result rather than a resign.
    Timeout {
        loser_white: bool,
    },
    /// Host-authoritative non-clock result. Needed by late spectators because
    /// FEN alone does not carry repetition history.
    GameOver {
        result: String,
    },
    // ---- Bughouse (4 players, 2 boards, host-authoritative) ----
    /// Host → each client: seat assignment + the four player names. Seats are
    /// indexed 0=A-White, 1=A-Black, 2=B-White, 3=B-Black.
    BugStart {
        seats: Vec<PlayerProfile>,
        your_seats: Vec<u8>,
        base_minutes: u32,
        increment_seconds: u32,
    },
    /// A move or drop on `board` (0=A, 1=B). Drops use UCI "N@f3" form. Clocks
    /// are the host-authoritative board clocks after the move.
    BugMove {
        board: u8,
        uci: String,
        white_ms: i64,
        black_ms: i64,
    },
    /// Host → clients: a captured piece passed to the partner's reserve.
    /// `to_color` 0=white, 1=black; `piece` 0=Pawn..4=Queen.
    BugPass {
        to_board: u8,
        to_color: u8,
        piece: u8,
    },
    /// Host → clients: the match ended. `winning_team` 1 or 2.
    BugResult {
        winning_team: u8,
        reason: String,
        board: u8,
    },
    /// A seat resigns (forfeits its team).
    BugResign {
        seat: u8,
    },

    // ---- 4-player chess (host-authoritative; seats 0=Red,1=Blue,2=Yellow,3=Green) ----
    /// Host → each client: format ("ffa"/"teams") + the four names + this
    /// client's seats. A read-only spectator receives an empty seat list.
    FourStart {
        format: String,
        seats: Vec<PlayerProfile>,
        your_seats: Vec<u8>,
    },
    /// A move/castle/promotion on the cross board (UCI-like, e.g. "g1i1").
    FourMove {
        seat: u8,
        uci: String,
    },
    FourResign {
        seat: u8,
    },
    /// Host → clients: the match ended ("team:red_yellow" | "ffa:red" | ...).
    FourResult {
        result: String,
    },

    Resign,
    DrawOffer,
    DrawResponse {
        accepted: bool,
    },
    Ping {
        t: u64,
    },
    Pong {
        t: u64,
    },
    Rematch,
    Bye,
    Chat {
        text: String,
    },
    /// Spectator → host only. The host attaches the sender identity and relays
    /// it solely to other spectators as [`SpectatorChatBroadcast`].
    SpectatorChat {
        text: String,
    },
    /// Host → spectators only. Players never receive this private channel.
    SpectatorChatBroadcast {
        sender: String,
        text: String,
    },
}

impl Message {
    /// Serialize to a single newline-terminated JSON line.
    pub fn encode(&self) -> String {
        let mut s = serde_json::to_string(self).expect("serialize message");
        s.push('\n');
        s
    }

    /// Parse one JSON line.
    pub fn decode(line: &str) -> Result<Message, serde_json::Error> {
        if line.len() > MAX_MESSAGE_BYTES {
            return Err(serde_json::Error::io(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                "LAN message exceeds size limit",
            )));
        }
        serde_json::from_str(line.trim())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn round_trip(m: Message) {
        let line = m.encode();
        assert!(line.ends_with('\n'));
        assert_eq!(Message::decode(&line).unwrap(), m);
    }

    #[test]
    fn messages_round_trip() {
        let ada =
            PlayerProfile::from_avatar_bytes("Ada".into(), &[0xff, 0xd8, 0xff, 0xd9]).unwrap();
        let bob = PlayerProfile::from_avatar_bytes("Bob".into(), &[]).unwrap();
        round_trip(Message::Hello {
            profile: ada.clone(),
            protocol_version: PROTOCOL_VERSION,
            role: SessionRole::Player,
            base_minutes: 5,
            increment_seconds: 2,
        });
        round_trip(Message::Start {
            white_profile: ada.clone(),
            black_profile: bob.clone(),
            you_are_white: true,
            role: SessionRole::Player,
            base_minutes: 5,
            increment_seconds: 2,
            fen: chess_core::START_FEN.into(),
            variant: "standard".into(),
            white_ms: 300_000,
            black_ms: 300_000,
            variant_state: VariantState::EMPTY,
        });
        round_trip(Message::Move {
            uci: "e2e4".into(),
            ply: 1,
            white_ms: 300_000,
            black_ms: 300_000,
        });
        round_trip(Message::Timeout { loser_white: true });
        round_trip(Message::GameOver {
            result: "draw_threefold".into(),
        });
        round_trip(Message::BugStart {
            seats: vec![ada.clone(), bob.clone(), ada.clone(), bob.clone()],
            your_seats: vec![1, 2],
            base_minutes: 3,
            increment_seconds: 0,
        });
        round_trip(Message::BugMove {
            board: 1,
            uci: "N@f3".into(),
            white_ms: 180_000,
            black_ms: 175_000,
        });
        round_trip(Message::BugPass {
            to_board: 0,
            to_color: 1,
            piece: 4,
        });
        round_trip(Message::BugResult {
            winning_team: 2,
            reason: "checkmate".into(),
            board: 0,
        });
        round_trip(Message::BugResign { seat: 3 });
        round_trip(Message::FourStart {
            format: "ffa".into(),
            seats: vec![ada.clone(), bob.clone(), ada.clone(), bob],
            your_seats: vec![0],
        });
        round_trip(Message::FourMove {
            seat: 2,
            uci: "g1i1".into(),
        });
        round_trip(Message::FourResign { seat: 1 });
        round_trip(Message::FourResult {
            result: "ffa:red".into(),
        });
        round_trip(Message::Resign);
        round_trip(Message::DrawOffer);
        round_trip(Message::DrawResponse { accepted: true });
        round_trip(Message::Ping { t: 42 });
        round_trip(Message::Bye);
        round_trip(Message::Chat { text: "gg".into() });
        round_trip(Message::SpectatorChat {
            text: "nice move".into(),
        });
        round_trip(Message::SpectatorChatBroadcast {
            sender: "Ada".into(),
            text: "nice move".into(),
        });
        round_trip(Message::Reject {
            reason: "spectators are disabled".into(),
        });
        round_trip(Message::SpectatorJoined { profile: ada });
    }

    #[test]
    fn move_tag_is_snake_case() {
        let line = Message::Resign.encode();
        assert!(line.contains("\"type\":\"resign\""));
    }

    #[test]
    fn profile_round_trips_and_rejects_oversized_avatar() {
        let avatar = [0xff, 0xd8, 0xff, 0xd9];
        let profile = PlayerProfile::from_avatar_bytes("player".into(), &avatar).unwrap();
        assert_eq!(profile.avatar_bytes().unwrap(), avatar);
        assert!(
            PlayerProfile::from_avatar_bytes("player".into(), &vec![0; MAX_AVATAR_BYTES + 1],)
                .is_err()
        );
        assert!(PlayerProfile::from_avatar_bytes("player".into(), &[1, 2, 3]).is_err());
    }

    #[test]
    fn oversized_message_is_rejected() {
        let line = "x".repeat(MAX_MESSAGE_BYTES + 1);
        assert!(Message::decode(&line).is_err());
    }

    #[test]
    fn unicode_names_follow_the_ui_character_limit() {
        let valid = "界".repeat(MAX_USERNAME_CHARS);
        assert!(PlayerProfile::from_avatar_bytes(valid, &[]).is_ok());
        let too_long = "界".repeat(MAX_USERNAME_CHARS + 1);
        assert!(PlayerProfile::from_avatar_bytes(too_long, &[]).is_err());
    }
}

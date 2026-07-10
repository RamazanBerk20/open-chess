//! `chess_net` — LAN discovery + multiplayer protocol.
//!
//! mDNS service discovery (`_open-chess._tcp`) and a newline-delimited JSON message
//! protocol. Pure of any bridge/Flutter dependency; the `chess_api` layer drives
//! the TCP connection and validates every incoming move against `chess_core`.

pub mod discovery;
pub mod protocol;

pub use discovery::{advertise, browse, Advertiser, Browser, DiscoveredHost, HostAdvertisement};
pub use protocol::{
    Message, PlayerProfile, SessionRole, VariantState, MAX_AVATAR_BYTES, MAX_MESSAGE_BYTES,
    MAX_USERNAME_BYTES, PROTOCOL_VERSION, SERVICE_TYPE,
};

#[derive(thiserror::Error, Debug)]
pub enum NetError {
    #[error("mDNS error: {0}")]
    Mdns(String),
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),
}

impl From<mdns_sd::Error> for NetError {
    fn from(e: mdns_sd::Error) -> Self {
        NetError::Mdns(e.to_string())
    }
}

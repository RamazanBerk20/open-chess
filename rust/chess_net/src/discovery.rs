//! mDNS advertise/browse for `_open-chess._tcp` hosts.

use std::sync::mpsc::Receiver;

use mdns_sd::{ServiceDaemon, ServiceEvent, ServiceInfo};

use crate::protocol::{PROTOCOL_VERSION, SERVICE_TYPE};
use crate::NetError;

/// Keeps a registered service alive; unregisters on drop.
pub struct Advertiser {
    daemon: ServiceDaemon,
    fullname: String,
    advertisement: HostAdvertisement,
    port: u16,
}

/// Metadata exposed through mDNS. The connection address remains an internal
/// field on [DiscoveredHost]; UI callers should render this metadata instead.
#[derive(Clone, Debug)]
pub struct HostAdvertisement {
    pub name: String,
    pub mode: String,
    pub variant: String,
    pub base_minutes: u32,
    pub increment_seconds: u32,
    pub allow_spectators: bool,
    /// Connected players, excluding read-only spectators.
    pub player_count: u32,
    /// Number of playing seats this match supports.
    pub max_players: u32,
}

fn service_info(ad: &HostAdvertisement, port: u16) -> Result<ServiceInfo, NetError> {
    let instance = sanitize(&format!("{}-{}", ad.mode, ad.name));
    let host = format!("{instance}.local.");
    let tc = format!("{}+{}", ad.base_minutes, ad.increment_seconds);
    let spectators = if ad.allow_spectators { "1" } else { "0" };
    let version = PROTOCOL_VERSION.to_string();
    let max_players = ad.max_players.max(1).to_string();
    let player_count = ad.player_count.clamp(1, ad.max_players.max(1)).to_string();
    let props: [(&str, &str); 8] = [
        ("name", &ad.name),
        ("mode", &ad.mode),
        ("variant", &ad.variant),
        ("tc", &tc),
        ("spectators", spectators),
        ("players", &player_count),
        ("capacity", &max_players),
        ("ver", &version),
    ];

    Ok(ServiceInfo::new(SERVICE_TYPE, &instance, &host, "", port, &props[..])?.enable_addr_auto())
}

/// Advertise a host on the LAN. `port` is the TCP port peers connect to.
pub fn advertise(ad: HostAdvertisement, port: u16) -> Result<Advertiser, NetError> {
    let daemon = ServiceDaemon::new()?;
    let info = service_info(&ad, port)?;
    let fullname = info.get_fullname().to_string();
    daemon.register(info)?;
    Ok(Advertiser {
        daemon,
        fullname,
        advertisement: ad,
        port,
    })
}

impl Advertiser {
    /// Re-announce current lobby capacity. `mdns-sd` updates an existing
    /// service when the same full name is registered again.
    pub fn update_player_count(&mut self, player_count: u32) -> Result<(), NetError> {
        self.update_availability(player_count, self.advertisement.allow_spectators)
    }

    /// Update the join/spectate availability exposed by discovery without
    /// changing the stable service identity. Hosts use this when a lobby turns
    /// into a live match: normal joins close while spectating can open.
    pub fn update_availability(
        &mut self,
        player_count: u32,
        allow_spectators: bool,
    ) -> Result<(), NetError> {
        self.advertisement.player_count = player_count;
        self.advertisement.allow_spectators = allow_spectators;
        let info = service_info(&self.advertisement, self.port)?;
        debug_assert_eq!(info.get_fullname(), self.fullname);
        self.daemon.register(info)?;
        Ok(())
    }
}

impl Drop for Advertiser {
    fn drop(&mut self) {
        let _ = self.daemon.unregister(&self.fullname);
        let _ = self.daemon.shutdown();
    }
}

/// A discovered host on the LAN.
#[derive(Clone, Debug)]
pub struct DiscoveredHost {
    pub name: String,
    pub addr: String, // "ip:port"
    pub time_control: String,
    pub mode: String,
    pub variant: String,
    pub spectators_enabled: bool,
    pub player_count: u32,
    pub max_players: u32,
}

/// Keeps a browse session alive; stops on drop.
pub struct Browser {
    daemon: ServiceDaemon,
}

impl Drop for Browser {
    fn drop(&mut self) {
        let _ = self.daemon.stop_browse(SERVICE_TYPE);
        let _ = self.daemon.shutdown();
    }
}

/// Browse for Open Chess hosts. Returns a handle (drop to stop) and a channel of
/// resolved hosts. A background thread translates mDNS events.
pub fn browse() -> Result<(Browser, Receiver<DiscoveredHost>), NetError> {
    let daemon = ServiceDaemon::new()?;
    let events = daemon.browse(SERVICE_TYPE)?;
    let (tx, rx) = std::sync::mpsc::channel();

    std::thread::spawn(move || {
        while let Ok(event) = events.recv() {
            if let ServiceEvent::ServiceResolved(info) = event {
                // Game listeners currently bind IPv4 (`0.0.0.0`), so prefer a
                // resolved IPv4 address rather than emitting an invalid
                // unbracketed IPv6 `ip:port` target on dual-stack networks.
                let Some(ip) = info
                    .get_addresses()
                    .iter()
                    .find(|address| address.is_ipv4())
                else {
                    continue;
                };
                let mode = info
                    .get_property_val_str("mode")
                    .unwrap_or("two_player")
                    .to_string();
                let (player_count, max_players) = player_counts(
                    &mode,
                    info.get_property_val_str("players"),
                    info.get_property_val_str("capacity"),
                );
                let host = DiscoveredHost {
                    name: info
                        .get_property_val_str("name")
                        .unwrap_or("Open Chess host")
                        .to_string(),
                    addr: format!("{ip}:{}", info.get_port()),
                    time_control: info.get_property_val_str("tc").unwrap_or("?").to_string(),
                    mode,
                    variant: info
                        .get_property_val_str("variant")
                        .unwrap_or("standard")
                        .to_string(),
                    spectators_enabled: info
                        .get_property_val_str("spectators")
                        .is_some_and(|value| value == "1"),
                    player_count,
                    max_players,
                };
                if tx.send(host).is_err() {
                    break; // consumer dropped
                }
            }
        }
    });

    Ok((Browser { daemon }, rx))
}

fn player_counts(mode: &str, players: Option<&str>, capacity: Option<&str>) -> (u32, u32) {
    let default_capacity = match mode {
        "bughouse" | "four_player" => 4,
        _ => 2,
    };
    let max_players = capacity
        .and_then(|value| value.parse::<u32>().ok())
        .filter(|&value| value > 0)
        .unwrap_or(default_capacity);
    let player_count = players
        .and_then(|value| value.parse::<u32>().ok())
        .filter(|&value| value > 0)
        .unwrap_or(1)
        .min(max_players);
    (player_count, max_players)
}

/// mDNS instance names can't contain dots/spaces; replace them.
fn sanitize(name: &str) -> String {
    let cleaned: String = name
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { '-' })
        .collect();
    if cleaned.is_empty() {
        "open-chess".to_string()
    } else {
        cleaned
    }
}

#[cfg(test)]
mod tests {
    use super::player_counts;

    #[test]
    fn player_counts_clamp_and_fall_back_by_mode() {
        assert_eq!(player_counts("two_player", Some("2"), Some("2")), (2, 2));
        assert_eq!(player_counts("bughouse", Some("9"), Some("4")), (4, 4));
        assert_eq!(player_counts("four_player", None, None), (1, 4));
        assert_eq!(player_counts("two_player", Some("bad"), Some("0")), (1, 2));
    }
}

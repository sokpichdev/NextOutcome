//
//  EsportsLeague.swift
//  NextOutcome
//
//  Created by Sok Pich on 09/08/2026.
//

import Foundation

/// One game title in Polymarket's esports catalogue — CS2, Dota 2, Valorant and so on.
///
/// Sourced from Gamma's `/sports` league catalogue rather than hardcoded. That endpoint is
/// what lets the hub grow a tile the day Polymarket adds a game, and it supplies the two
/// things a hand-written list can't: the canonical classification tag and real key art.
public struct EsportsLeague: Identifiable, Hashable, Sendable {
    /// The league's slug (`"cs2"`, `"dota2"`, `"val"`), unique across the catalogue.
    public let id: String
    /// The display name shown on the tile and match cards ("CS2", "Mobile Legends: Bang Bang").
    public let name: String
    /// The Gamma tag id that identifies this game's events — Gamma's own answer to "which
    /// tag means this league", so classification doesn't have to guess between slugs.
    ///
    /// Load-bearing: game tags on events are not consistent. CS2 events carry `cs2`
    /// (id `100677`), `counter-strike-2` (id `100780`) and even the typo `counter-stike-2`.
    /// Matching this id sidesteps all of it — the catalogue names `100780` as primary.
    public let primaryTagID: String
    /// The Gamma series id for the league's tournaments, when it has one. Unused today;
    /// it's the key to a per-league tournament row (`/events?series_id=`).
    public let seriesID: String?
    /// The league's key art, hosted by Polymarket. `nil` when the catalogue omits it.
    public let iconURL: URL?

    /// Creates a league.
    public init(id: String, name: String, primaryTagID: String, seriesID: String? = nil, iconURL: URL? = nil) {
        self.id = id
        self.name = name
        self.primaryTagID = primaryTagID
        self.seriesID = seriesID
        self.iconURL = iconURL
    }
}

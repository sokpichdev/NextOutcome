//
//  SportLeague.swift
//  NextOutcome
//

import Foundation

/// One league in Polymarket's catalogue — MLB, LaLiga, CS2, Setka Cup — joined from Gamma's
/// `/sports` (identity, tags, key art) and `/sports/summary` (activity).
///
/// Sourced from the server rather than hardcoded, which is what lets a hub grow a chip the
/// day Polymarket adds a league, and supplies the two things a hand-written list cannot: the
/// canonical classification tag and real key art.
public struct SportLeague: Identifiable, Hashable, Sendable {
    /// The league's slug (`"mlb"`, `"lal"`, `"cs2"`), unique across the catalogue and the
    /// key both endpoints agree on.
    public let id: String
    /// The display name shown on chips and cards ("MLB", "Mobile Legends: Bang Bang").
    public let name: String
    /// The Gamma tag id identifying this league's events — Gamma's own answer to "which tag
    /// means this league", so classification doesn't have to guess between slugs.
    ///
    /// Load-bearing: game tags on events are not consistent. CS2 events carry `cs2`
    /// (id `100677`), `counter-strike-2` (id `100780`) and even the typo `counter-stike-2`.
    /// Matching this id sidesteps all of it — the catalogue names `100780` as primary.
    public let primaryTagID: String
    /// The tag id of the sport this league belongs to (Soccer, Cricket, …), or `nil` when
    /// it belongs to none.
    ///
    /// `nil` is a normal, meaningful value, not a failure: MLB carries its own tag rather
    /// than baseball's, so it becomes a top-level row of its own. See `SportGroupCatalog`.
    public let groupTagID: String?
    /// The Gamma series id for the league's tournaments, when it has one.
    public let seriesID: String?
    /// The league's key art, hosted by Polymarket. `nil` when the catalogue omits it.
    public let iconURL: URL?
    /// Open events under this league right now — the chip's count badge. `0` when the
    /// summary has no row for it.
    public let activeEventCount: Int
    /// Whether any of those events is in play — drives the live dot.
    public let hasLive: Bool
    /// Total traded volume, used to rank chips and groups.
    public let volume: Decimal
    /// ISO-8601 day strings this league has events on. Empty when dormant.
    public let eventDates: [String]

    /// Creates a league. Every field after `primaryTagID` defaults, so callers that only
    /// know a league's identity (the esports hub, tests) need not supply activity data.
    public init(
        id: String,
        name: String,
        primaryTagID: String,
        groupTagID: String? = nil,
        seriesID: String? = nil,
        iconURL: URL? = nil,
        activeEventCount: Int = 0,
        hasLive: Bool = false,
        volume: Decimal = 0,
        eventDates: [String] = []
    ) {
        self.id = id
        self.name = name
        self.primaryTagID = primaryTagID
        self.groupTagID = groupTagID
        self.seriesID = seriesID
        self.iconURL = iconURL
        self.activeEventCount = activeEventCount
        self.hasLive = hasLive
        self.volume = volume
        self.eventDates = eventDates
    }
}

/// The Esports hub's name for the same catalogue entry.
///
/// Both hubs read one `/sports` catalogue, so they share one entity. This alias keeps the
/// esports-facing vocabulary (and every existing call site) intact.
public typealias EsportsLeague = SportLeague

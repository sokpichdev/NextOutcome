//
//  SportsSummaryDTO.swift
//  NextOutcome
//

import Foundation

/// Gamma's `GET /sports/summary` — the payload behind Polymarket's sports nav row.
///
/// Takes no parameters and returns every league at once (~100KB, 439 rows). This is the
/// endpoint that supplies what `/sports` alone cannot: how many events a league has open
/// right now, whether any of them is in play, and how much it has traded. Those three
/// fields are the entire reason the reference nav can show "MLB 130" and a live dot.
///
/// ```json
/// {"leagues": {"mlb": {"name": "MLB", "activeEventCount": 118, "hasLive": true,
///                      "eventDates": ["2026-08-16"], "volume": 5957601}}}
/// ```
struct SportsSummaryDTO: Decodable {
    /// One league's activity summary.
    struct League: Decodable {
        /// Display name ("MLB", "Big Bash League").
        let name: String?
        /// League key-art URL string.
        let image: String?
        /// Open (non-closed) events under this league right now — the chip's count badge.
        let activeEventCount: Int?
        /// Whether any of those events is currently in play — the chip's live dot.
        let hasLive: Bool?
        /// ISO-8601 day strings the league has events on. **Absent, not null or empty, for
        /// dormant leagues** — every field here is optional for that reason.
        let eventDates: [String]?
        /// The earliest day with an open event, if any.
        let earliestOpenDate: String?
        /// Total traded volume, used to rank chips.
        let volume: Double?
    }

    /// Every league, keyed by its slug — the same slug `/sports` calls `sport`, which is
    /// what lets the two endpoints be joined.
    let leagues: [String: League]
}

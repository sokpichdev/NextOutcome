//
//  SportsFrameDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//
//  Decoded from real frames captured off `wss://sports-api.polymarket.com/ws`, e.g.
//    {"metadataGameId":"id...","leagueAbbreviation":"cricket","score":"156-156",
//     "period":"Scheduled","live":false,"ended":false}
//  Non-state traffic (PING/PONG, frames without `metadataGameId`) decodes tolerantly and
//  is skipped by the mapper rather than throwing.
//

import Foundation
import LiveStatsDomain

/// The raw JSON shape of one WebSocket frame from the sports feed. Every field is
/// optional because the feed mixes per-game state frames with control traffic
/// (PING/PONG) that carries none of these keys.
struct SportsFrameDTO: Decodable {
    /// The game's unique ID on the frames that carry one under this key (soccer, cricket, …).
    let metadataGameId: String?
    /// The game's unique ID on **esports** frames, which name it `gameId` and send it as a
    /// number. Captured verbatim off the feed:
    ///   {"gameId":1616952,"leagueAbbreviation":"cs2","score":"000-000|1-1|Bo3",
    ///    "period":"3/3","live":true,"ended":false}
    let gameId: Int?
    /// The league/competition abbreviation (e.g. "cricket").
    let leagueAbbreviation: String?
    /// The score as a `"home-away"` string (e.g. "156-156"), if present.
    let score: String?
    /// The current period label, if present.
    let period: String?
    /// Whether the match is live, if present.
    let live: Bool?
    /// Whether the match has ended, if present.
    let ended: Bool?
    /// The finish timestamp, if the match has ended.
    let finishedTimestamp: String?
}

extension SportsFrameDTO {
    /// The frame's game identifier, whichever key it arrived under. `nil` means this frame
    /// isn't per-game state (PING/PONG and other control traffic) and should be skipped.
    ///
    /// Esports frames carry only `gameId`; before it was read here, every esports frame was
    /// silently dropped and the esports live socket delivered nothing at all.
    var identifier: String? {
        metadataGameId ?? gameId.map(String.init)
    }

    /// Maps a decoded frame to a `MatchState` snapshot, carrying forward fields the feed
    /// does not resend from `previous`. Returns `nil` for frames that are not per-game
    /// state (no identifier) so the socket can skip them.
    func toMatchState(previous: MatchState?) -> MatchState? {
        guard let gameID = identifier else { return nil }
        let parsed = MatchState.parseScore(score)
        return MatchState(
            gameID: gameID,
            rawScore: score ?? previous?.rawScore,
            league: leagueAbbreviation ?? previous?.league,
            period: period ?? previous?.period,
            clockMinute: previous?.clockMinute,
            isLive: live ?? previous?.isLive ?? false,
            ended: ended ?? previous?.ended ?? false,
            home: MatchState.TeamStats(goals: parsed?.home ?? previous?.home.goals ?? 0),
            away: MatchState.TeamStats(goals: parsed?.away ?? previous?.away.goals ?? 0),
            events: previous?.events ?? [],
            lineups: previous?.lineups,
            commentary: previous?.commentary,
            ballPositionPct: previous?.ballPositionPct
        )
    }
}

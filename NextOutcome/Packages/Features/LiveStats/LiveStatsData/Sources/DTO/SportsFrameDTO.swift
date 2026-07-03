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

struct SportsFrameDTO: Decodable {
    let metadataGameId: String?
    let leagueAbbreviation: String?
    let score: String?
    let period: String?
    let live: Bool?
    let ended: Bool?
    let finishedTimestamp: String?
}

extension SportsFrameDTO {
    /// Maps a decoded frame to a `MatchState` snapshot, carrying forward fields the feed
    /// does not resend from `previous`. Returns `nil` for frames that are not per-game
    /// state (no `metadataGameId`) so the socket can skip them.
    func toMatchState(previous: MatchState?) -> MatchState? {
        guard let gameID = metadataGameId else { return nil }
        let parsed = MatchState.parseScore(score)
        return MatchState(
            gameID: gameID,
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

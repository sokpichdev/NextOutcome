//
//  GameResult.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import Foundation

/// One side of a game from Gamma's `/events/results` sports feed.
public struct GameTeam: Hashable, Sendable {
    public let name: String
    public let abbreviation: String?
    public let logoURL: URL?
    public let colorHex: String?
    /// "home" or "away" per Gamma's `ordering`.
    public let ordering: String

    public init(name: String, abbreviation: String?, logoURL: URL?, colorHex: String?, ordering: String) {
        self.name = name
        self.abbreviation = abbreviation
        self.logoURL = logoURL
        self.colorHex = colorHex
        self.ordering = ordering
    }
}

/// Live/final state of a sports game event from `/events/results`: score, period, and teams.
public struct GameResult: Hashable, Sendable {
    public let eventID: String
    /// "home-away", e.g. "3-2". Nil when the game hasn't started.
    public let score: String?
    public let elapsed: String?
    public let period: String?
    public let live: Bool
    public let ended: Bool
    public let teams: [GameTeam]

    public init(eventID: String, score: String?, elapsed: String?, period: String?, live: Bool, ended: Bool, teams: [GameTeam]) {
        self.eventID = eventID
        self.score = score
        self.elapsed = elapsed
        self.period = period
        self.live = live
        self.ended = ended
        self.teams = teams
    }

    public var homeTeam: GameTeam? { teams.first { $0.ordering == "home" } }
    public var awayTeam: GameTeam? { teams.first { $0.ordering == "away" } }

    public var homeScore: Int? { scoreComponents?.home }
    public var awayScore: Int? { scoreComponents?.away }

    private var scoreComponents: (home: Int, away: Int)? {
        guard let score else { return nil }
        let parts = score.split(separator: "-")
        guard parts.count == 2, let home = Int(parts[0]), let away = Int(parts[1]) else { return nil }
        return (home, away)
    }
}

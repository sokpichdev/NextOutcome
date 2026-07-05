//
//  GameResult.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import Foundation

/// One side of a game from Gamma's `/events/results` sports feed.
public struct GameTeam: Hashable, Sendable {
    /// The team's full name.
    public let name: String
    /// The team's short abbreviation, if any.
    public let abbreviation: String?
    /// The team's logo image, if any.
    public let logoURL: URL?
    /// The team's brand colour as a hex string, if any.
    public let colorHex: String?
    /// "home" or "away" per Gamma's `ordering`.
    public let ordering: String

    /// Creates a game team.
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
    /// The event id this result belongs to.
    public let eventID: String
    /// "home-away", e.g. "3-2". Nil when the game hasn't started.
    public let score: String?
    /// Elapsed-time label (e.g. "72'"), if provided.
    public let elapsed: String?
    /// The current period label, if provided.
    public let period: String?
    /// Whether the game is currently live.
    public let live: Bool
    /// Whether the game has ended.
    public let ended: Bool
    /// The teams playing (home and away).
    public let teams: [GameTeam]

    /// Creates a game result.
    public init(eventID: String, score: String?, elapsed: String?, period: String?, live: Bool, ended: Bool, teams: [GameTeam]) {
        self.eventID = eventID
        self.score = score
        self.elapsed = elapsed
        self.period = period
        self.live = live
        self.ended = ended
        self.teams = teams
    }

    /// The home team, if present.
    public var homeTeam: GameTeam? { teams.first { $0.ordering == "home" } }
    /// The away team, if present.
    public var awayTeam: GameTeam? { teams.first { $0.ordering == "away" } }

    /// The home team's score parsed from `score`, or `nil` if unavailable.
    public var homeScore: Int? { scoreComponents?.home }
    /// The away team's score parsed from `score`, or `nil` if unavailable.
    public var awayScore: Int? { scoreComponents?.away }

    /// Parses the `"home-away"` score string into a pair of ints, or `nil` if malformed.
    private var scoreComponents: (home: Int, away: Int)? {
        guard let score else { return nil }
        let parts = score.split(separator: "-")
        guard parts.count == 2, let home = Int(parts[0]), let away = Int(parts[1]) else { return nil }
        return (home, away)
    }
}

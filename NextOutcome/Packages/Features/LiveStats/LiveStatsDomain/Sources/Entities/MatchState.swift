//
//  MatchState.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import Foundation

/// Live connection lifecycle for the sports feed, observed by the view model.
/// The socket owns all reconnect/backoff timing; consumers only observe.
public enum MatchConnection: Sendable, Equatable {
    case live
    case reconnecting
}

/// The Presentation-facing contract for a live match.
///
/// The public sports feed (`wss://sports-api.polymarket.com/ws`) delivers full-state
/// snapshots carrying only `score`, `period`, `live`, and `ended`. The richer fields
/// (cards, shots, lineups, commentary, ball position, per-event timeline) are modelled
/// here so the Live sub-tab can code against a stable contract, but stay `nil` whenever
/// the feed does not provide them — an in-spec "Not available for this match" degradation,
/// not a bug.
public struct MatchState: Sendable, Equatable {
    public struct TeamStats: Sendable, Equatable {
        public var goals: Int
        public var yellowCards: Int?
        public var redCards: Int?
        public var shotsOn: Int?
        public var shotsOff: Int?
        public var shotsBlocked: Int?
        public var corners: Int?

        public init(
            goals: Int = 0,
            yellowCards: Int? = nil,
            redCards: Int? = nil,
            shotsOn: Int? = nil,
            shotsOff: Int? = nil,
            shotsBlocked: Int? = nil,
            corners: Int? = nil
        ) {
            self.goals = goals
            self.yellowCards = yellowCards
            self.redCards = redCards
            self.shotsOn = shotsOn
            self.shotsOff = shotsOff
            self.shotsBlocked = shotsBlocked
            self.corners = corners
        }
    }

    public enum EventKind: String, Sendable, Equatable {
        case goal, yellowCard, redCard, substitution
    }

    public struct MatchEvent: Sendable, Equatable {
        public let minute: Int
        public let kind: EventKind
        public let home: Bool
        public init(minute: Int, kind: EventKind, home: Bool) {
            self.minute = minute
            self.kind = kind
            self.home = home
        }
    }

    public struct Lineups: Sendable, Equatable {
        public let homeFormation: String?
        public let awayFormation: String?
        public let homeStarters: [String]
        public let awayStarters: [String]
        public init(
            homeFormation: String? = nil,
            awayFormation: String? = nil,
            homeStarters: [String] = [],
            awayStarters: [String] = []
        ) {
            self.homeFormation = homeFormation
            self.awayFormation = awayFormation
            self.homeStarters = homeStarters
            self.awayStarters = awayStarters
        }
    }

    public struct CommentaryItem: Sendable, Equatable {
        public let minute: Int?
        public let text: String
        public init(minute: Int?, text: String) {
            self.minute = minute
            self.text = text
        }
    }

    public var gameID: String
    public var league: String?
    public var period: String?
    public var clockMinute: Int?
    public var isLive: Bool
    public var ended: Bool
    public var home: TeamStats
    public var away: TeamStats
    public var events: [MatchEvent]
    public var lineups: Lineups?
    public var commentary: [CommentaryItem]?
    public var ballPositionPct: Double?

    public init(
        gameID: String,
        league: String? = nil,
        period: String? = nil,
        clockMinute: Int? = nil,
        isLive: Bool = false,
        ended: Bool = false,
        home: TeamStats = .init(),
        away: TeamStats = .init(),
        events: [MatchEvent] = [],
        lineups: Lineups? = nil,
        commentary: [CommentaryItem]? = nil,
        ballPositionPct: Double? = nil
    ) {
        self.gameID = gameID
        self.league = league
        self.period = period
        self.clockMinute = clockMinute
        self.isLive = isLive
        self.ended = ended
        self.home = home
        self.away = away
        self.events = events
        self.lineups = lineups
        self.commentary = commentary
        self.ballPositionPct = ballPositionPct
    }

    /// Parses a feed score string like `"127-132"` or `"1-0"` into home/away integers.
    /// Returns `nil` when the string is not a `<int>-<int>` pair.
    public static func parseScore(_ raw: String?) -> (home: Int, away: Int)? {
        guard let raw else { return nil }
        let parts = raw.split(separator: "-", maxSplits: 1)
        guard parts.count == 2,
              let home = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let away = Int(parts[1].trimmingCharacters(in: .whitespaces))
        else { return nil }
        return (home, away)
    }
}

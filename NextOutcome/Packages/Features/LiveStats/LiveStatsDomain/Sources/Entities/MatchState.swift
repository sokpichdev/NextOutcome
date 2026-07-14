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
    /// Connected and receiving live snapshots.
    case live
    /// Not currently connected — the socket is (re)establishing the connection.
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
    /// Per-team statistics. Only `goals` is always present; everything else is optional
    /// because the public feed often omits it (shown as "—" in the UI when `nil`).
    public struct TeamStats: Sendable, Equatable {
        /// Goals scored (always available).
        public var goals: Int
        /// Yellow cards, if reported.
        public var yellowCards: Int?
        /// Red cards, if reported.
        public var redCards: Int?
        /// Shots on target, if reported.
        public var shotsOn: Int?
        /// Shots off target, if reported.
        public var shotsOff: Int?
        /// Shots blocked, if reported.
        public var shotsBlocked: Int?
        /// Corner kicks, if reported.
        public var corners: Int?

        /// Creates a team-stats snapshot. Every field except `goals` defaults to
        /// unavailable (`nil`).
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

    /// The kinds of timeline event the feed can report.
    public enum EventKind: String, Sendable, Equatable {
        case goal, yellowCard, redCard, substitution
    }

    /// A single event on the match timeline (e.g. a goal in the 34th minute).
    public struct MatchEvent: Sendable, Equatable {
        /// The match minute the event happened at.
        public let minute: Int
        /// What kind of event it was.
        public let kind: EventKind
        /// `true` if it was the home team's event, `false` for the away team.
        public let home: Bool
        /// Creates a timeline event.
        public init(minute: Int, kind: EventKind, home: Bool) {
            self.minute = minute
            self.kind = kind
            self.home = home
        }
    }

    /// Starting formations and starters for both teams, when the feed provides them.
    public struct Lineups: Sendable, Equatable {
        /// The home team's formation string (e.g. "4-3-3"), if known.
        public let homeFormation: String?
        /// The away team's formation string, if known.
        public let awayFormation: String?
        /// The home team's starting player names.
        public let homeStarters: [String]
        /// The away team's starting player names.
        public let awayStarters: [String]
        /// Creates a lineups snapshot; all fields default to empty/unknown.
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

    /// A single line of live text commentary.
    public struct CommentaryItem: Sendable, Equatable {
        /// The match minute the comment refers to, if any.
        public let minute: Int?
        /// The commentary text.
        public let text: String
        /// Creates a commentary item.
        public init(minute: Int?, text: String) {
            self.minute = minute
            self.text = text
        }
    }

    /// The feed's unique identifier for this game.
    public var gameID: String
    /// The feed's raw score string, unparsed. Soccer/basketball send `"1-0"` (also parsed
    /// into `home.goals`/`away.goals`); esports send a composite `"000-000|1-0|Bo3"` that
    /// `parseScore` rejects, so consumers needing the map/series breakdown read this.
    public var rawScore: String?
    /// The competition/league name, if provided.
    public var league: String?
    /// The current period label (e.g. "1H", "HT", "2H"), if provided.
    public var period: String?
    /// The current match clock minute, if provided.
    public var clockMinute: Int?
    /// Whether the match is currently live.
    public var isLive: Bool
    /// Whether the match has finished.
    public var ended: Bool
    /// The home team's stats.
    public var home: TeamStats
    /// The away team's stats.
    public var away: TeamStats
    /// The timeline of notable events so far.
    public var events: [MatchEvent]
    /// Team lineups, if the feed supplied them.
    public var lineups: Lineups?
    /// Live commentary lines, if the feed supplied them.
    public var commentary: [CommentaryItem]?
    /// Approximate ball position as a 0–100 percentage across the pitch, if provided.
    public var ballPositionPct: Double?

    /// Creates a match-state snapshot. Every field beyond `gameID` defaults to the
    /// "not available" value so callers can build partial snapshots as the feed fills in.
    public init(
        gameID: String,
        rawScore: String? = nil,
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
        self.rawScore = rawScore
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

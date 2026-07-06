//
//  TeamProfileViewModel.swift
//  NextOutcome
//

import Foundation
import MarketsDomain

/// Drives the team/fighter profile screen: name/record header, upcoming match, and
/// match history — derived entirely from data already fetched elsewhere (the Sports
/// hub's broad event sample, plus the existing `/teams` league directory). No new
/// endpoints; see `TeamProfileTarget` for what's deliberately left out (bio fields,
/// About/FAQ copy — not available from Gamma's public API).
@MainActor
@Observable
public final class TeamProfileViewModel {
    /// The screen's load state.
    public enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// A future, unresolved game against this team.
    public struct Match: Identifiable, Hashable {
        /// The game event.
        public let event: Event
        /// The opposing team/fighter's name.
        public let opponentName: String
        public var id: String { event.id }
    }

    /// A resolved past game against this team.
    public struct MatchRecord: Identifiable, Hashable {
        /// The game event.
        public let event: Event
        /// The opposing team/fighter's name.
        public let opponentName: String
        /// Whether this team won.
        public let won: Bool
        public var id: String { event.id }
    }

    /// The tapped team this screen is showing.
    public let target: TeamProfileTarget
    /// The current load state.
    public private(set) var state: State = .idle
    /// The team's win-loss record (e.g. "27-9-0"), once loaded. `nil` when `target.league`
    /// is nil (no team directory for this league) or no matching team was found in it.
    public private(set) var record: String?
    /// The soonest unresolved match against this team, if any.
    public private(set) var upcomingMatch: Match?
    /// Resolved past matches against this team, most recent first.
    public private(set) var matchHistory: [MatchRecord] = []

    /// Loads the broad sports sample used to find this team's games.
    private let fetchAllEvents: FetchAllEventsUseCase
    /// Loads a league's team directory (for the record lookup).
    private let fetchTeams: FetchTeamsUseCase

    /// Creates the view model.
    /// - Parameters:
    ///   - target: The tapped team.
    ///   - fetchAllEvents: Use case for the broad sports sample.
    ///   - fetchTeams: Use case for the league's team directory.
    public init(target: TeamProfileTarget, fetchAllEvents: FetchAllEventsUseCase, fetchTeams: FetchTeamsUseCase) {
        self.target = target
        self.fetchAllEvents = fetchAllEvents
        self.fetchTeams = fetchTeams
    }

    /// Loads on first appearance only (no-op once loaded/loading).
    public func loadIfNeeded() async {
        if case .idle = state { await load() }
    }

    /// Fetches the broad sports sample and (when the league is known) the team
    /// directory, then finds this team's matches.
    public func load() async {
        state = .loading
        async let eventsTask = (try? await fetchAllEvents.execute(tagID: SportsHubViewModel.sportsTagID, status: .all)) ?? []
        async let recordTask = fetchRecord()
        let events = await eventsTask
        record = await recordTask
        let matches = Self.findMatches(for: target.name, in: events)
        upcomingMatch = matches.upcoming
        matchHistory = matches.history
        state = .loaded
    }

    /// Looks up this team's record from its league's team directory. Skipped entirely
    /// (returns nil without fetching) when `target.league` is nil.
    private func fetchRecord() async -> String? {
        guard let league = target.league else { return nil }
        let teams = (try? await fetchTeams.execute(league: league)) ?? []
        return teams.first { $0.name.caseInsensitiveCompare(target.name) == .orderedSame }?.record
    }

    /// Finds every event with a moneyline market for `teamName`, splitting into the
    /// soonest upcoming match and the resolved match history (most recent first).
    /// Pure and static so it's directly testable without a repository.
    /// - Parameters:
    ///   - teamName: The team/fighter to find matches for (matched case-insensitively).
    ///   - events: The candidate events (the Sports hub's broad sample).
    /// - Returns: The soonest upcoming match, and resolved history newest-first.
    static func findMatches(for teamName: String, in events: [Event]) -> (upcoming: Match?, history: [MatchRecord]) {
        struct Found {
            let event: Event
            let ownMarket: Market
            let opponentName: String
        }

        let found: [Found] = events.compactMap { event in
            let moneylines = WorldCupEventSplitter.moneylineMarkets(for: event)
            guard let ownMarket = moneylines.first(where: {
                $0.groupItemTitle?.caseInsensitiveCompare(teamName) == .orderedSame
            }) else { return nil }
            guard let opponentName = moneylines.first(where: {
                $0.id != ownMarket.id && $0.groupItemTitle?.lowercased().hasPrefix("draw") != true
            })?.groupItemTitle else { return nil }
            return Found(event: event, ownMarket: ownMarket, opponentName: opponentName)
        }

        let upcoming = found
            .filter { !$0.event.isResolved }
            .sorted { ($0.event.gameStartTime ?? .distantFuture) < ($1.event.gameStartTime ?? .distantFuture) }
            .first
            .map { Match(event: $0.event, opponentName: $0.opponentName) }

        let history = found
            .filter(\.event.isResolved)
            .sorted { ($0.event.gameStartTime ?? .distantPast) > ($1.event.gameStartTime ?? .distantPast) }
            .map { entry -> MatchRecord in
                let won = (entry.ownMarket.outcomes.max { $0.price < $1.price }?.title)
                    .map { $0.caseInsensitiveCompare("Yes") == .orderedSame } ?? false
                return MatchRecord(event: entry.event, opponentName: entry.opponentName, won: won)
            }

        return (upcoming, history)
    }
}

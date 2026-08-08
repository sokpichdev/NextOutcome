//
//  WorldCupHubViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import Foundation
import MarketsDomain
import SharedDomain

/// Drives the World Cup hub: loads the tournament's games, props/futures, group events, team
/// directory, and live results, then feeds the Games/Props/Bracket/Map sub-tabs. Polls live
/// scores while on screen.
@MainActor
@Observable
public final class WorldCupHubViewModel {
    /// The hub's overall load state.
    public enum State {
        /// Nothing loaded yet.
        case idle
        /// Loading the tournament data.
        case loading
        /// Data loaded.
        case loaded
        /// The load failed, with a user-facing message.
        case failed(String)
    }

    /// 2026 FIFA World Cup Gamma series (`/sports` → sport "fifwc"): games + player props.
    /// The tag feed adds what the series omits — tournament futures (winner, awards,
    /// groups) — and doubles as the fallback when the series lookup returns nothing.
    static let seriesID = "11433"
    static let futuresTagID = "519"
    /// The tournament-winner futures event backing the flag marquee, fetched directly —
    /// it is neither in the series nor reliably in the futures tag's top page.
    static let winnerSlug = "world-cup-winner"

    /// The current load state.
    public private(set) var state: State = .idle
    /// The upcoming/current games (schedulable events).
    public private(set) var games: [Event] = []
    /// Most-recent finished knockout games (the previous round), for the bracket's Round of 32.
    public private(set) var completedGames: [Event] = []
    /// The prop/futures events (winner, awards, player props, group futures).
    public private(set) var props: [Event] = []
    /// Live/final results keyed by event id.
    public private(set) var results: [String: GameResult] = [:]
    /// League team reference (logo, colour) keyed by lowercased name — fills flags/colours
    /// where a game result hasn't loaded (e.g. the bracket's advance board).
    public private(set) var teamsByName: [String: GameTeam] = [:]
    /// The tournament-winner futures event, backing the flag marquee.
    public private(set) var winnerEvent: Event?
    /// Per-group winner events (world-cup-group-{a…l}-winner), each listing its group's teams.
    public private(set) var groupEvents: [Event] = []
    /// When results were last refreshed (for a "last updated" label).
    public private(set) var lastUpdated: Date?
    /// The selected sub-tab.
    public var selectedTab: WorldCupTab = .games
    /// The selected Props sub-filter.
    public var selectedPropsFilter: PropsFilter = .all

    /// Loads a series' events.
    private let fetchSeriesEvents: FetchSeriesEventsUseCase
    /// Loads game results.
    private let fetchGameResults: FetchGameResultsUseCase
    /// Loads events by tag (futures).
    private let fetchEvents: FetchEventsUseCase
    /// Loads a single event by slug (winner, groups).
    private let fetchEvent: FetchEventUseCase
    /// Loads the league team directory.
    private let fetchTeams: FetchTeamsUseCase
    /// Loads the most-recent completed events.
    private let fetchCompleted: FetchCompletedEventsUseCase
    /// Injectable clock (defaults to `Date()`), for deterministic tests.
    private let now: @Sendable () -> Date

    /// Creates the view model with its use cases.
    public init(
        fetchSeriesEvents: FetchSeriesEventsUseCase,
        fetchGameResults: FetchGameResultsUseCase,
        fetchEvents: FetchEventsUseCase,
        fetchEvent: FetchEventUseCase,
        fetchTeams: FetchTeamsUseCase,
        fetchCompleted: FetchCompletedEventsUseCase,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fetchSeriesEvents = fetchSeriesEvents
        self.fetchGameResults = fetchGameResults
        self.fetchEvents = fetchEvents
        self.fetchEvent = fetchEvent
        self.fetchTeams = fetchTeams
        self.fetchCompleted = fetchCompleted
        self.now = now
    }

    /// The league code used for the team directory.
    static let league = "fifwc"

    /// The games grouped by calendar day for the Games schedule tab.
    public var gamesByDay: [(day: Date, games: [Event])] {
        WorldCupEventSplitter.gamesByDay(games)
    }

    /// Fallback winner lookup in the loaded props. Excludes award ("Golden Boot Winner")
    /// and group ("Group A Winner") events that also say "winner".
    static func heuristicWinner(in props: [Event]) -> Event? {
        props
            .filter {
                let t = $0.title.lowercased()
                return t.contains("winner") && !t.contains("golden") && !t.contains("group")
            }
            .max { $0.volume < $1.volume }
    }

    /// Loads on first appearance only (no-op once loaded/loading).
    public func loadIfNeeded() async {
        if case .idle = state { await load() }
    }

    /// Loads all the hub's data concurrently (series, futures, winner, teams, groups,
    /// completed games), splits events into games/props, then kicks off an initial results
    /// fetch. Fails only if both the series and futures come back empty.
    public func load() async {
        state = .loading
        async let seriesFetch = fetchSeriesEvents.execute(seriesID: Self.seriesID)
        async let futuresFetch = fetchEvents.execute(tagID: Self.futuresTagID, sort: .volume24h, status: .active)
        async let winnerFetch = fetchEvent.execute(slug: Self.winnerSlug)
        async let teamsFetch = fetchTeams.execute(league: Self.league)
        async let groupsFetch = loadGroupEvents()
        async let completedFetch = fetchCompleted.execute(seriesID: Self.seriesID)

        let series = (try? await seriesFetch) ?? []
        let futures = (try? await futuresFetch)?.items ?? []
        let winner = try? await winnerFetch
        groupEvents = await groupsFetch
        if let teams = try? await teamsFetch {
            teamsByName = Dictionary(teams.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })
        }
        guard !(series.isEmpty && futures.isEmpty) else {
            state = .failed("Couldn't load World Cup markets. Pull to refresh.")
            return
        }

        let seriesIDs = Set(series.map(\.id))
        let events = series + futures.filter { !seriesIDs.contains($0.id) }
        let split = WorldCupEventSplitter.split(events)
        games = split.games
        props = split.props
        winnerEvent = winner ?? Self.heuristicWinner(in: split.props)
        // The most-recent finished knockout round: completed events that are games,
        // newest first, capped to one round.
        completedGames = ((try? await completedFetch) ?? [])
            .filter { WorldCupEventSplitter.moneyline(for: $0) != nil && $0.isResolved }
            .prefix(16)
            .map { $0 }
        state = .loaded
        lastUpdated = now()
        await refreshResults(for: initialResultIDs() + completedGames.map(\.id))
    }

    /// Fetches the 12 group-winner events concurrently; missing groups are skipped.
    private func loadGroupEvents() async -> [Event] {
        await withTaskGroup(of: Event?.self) { group in
            for letter in "abcdefghijkl" {
                group.addTask { [fetchEvent] in
                    try? await fetchEvent.execute(slug: "world-cup-group-\(letter)-winner")
                }
            }
            var out: [Event] = []
            for await event in group { if let event { out.append(event) } }
            return out
        }
    }

    /// Reloads everything (pull-to-refresh).
    public func refresh() async {
        await load()
    }

    /// Poll loop driven by the view's `.task`, so it cancels when the hub leaves screen.
    public func pollResults() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            await refreshResults(for: liveRefreshIDs())
        }
    }

    /// Fetch scores for the given games; individual failures keep existing entries.
    /// Fetches scores for the given games and merges them in; individual failures keep the
    /// existing entries.
    /// - Parameter eventIDs: The game ids to refresh.
    func refreshResults(for eventIDs: [String]) async {
        guard !eventIDs.isEmpty else { return }
        guard let fresh = try? await fetchGameResults.execute(eventIDs: eventIDs) else { return }
        results.merge(fresh) { _, new in new }
        lastUpdated = now()
    }

    /// Games worth an initial score fetch: kickoff within ±1 day, bounded fan-out.
    /// - Parameters:
    ///   - windowHours: How far around now (± hours) a kickoff must fall to qualify.
    ///   - cap: The maximum number of ids to return.
    /// - Returns: Ids of games worth an immediate score fetch.
    func initialResultIDs(windowHours: Double = 24, cap: Int = 20) -> [String] {
        let reference = now()
        return games
            .filter {
                guard let kickoff = $0.gameStartTime else { return false }
                return abs(kickoff.timeIntervalSince(reference)) <= windowHours * 3600
            }
            .prefix(cap)
            .map(\.id)
    }

    /// Games whose score can still change: currently live, or kicked off in the last 3h
    /// (covers games the initial fetch saw as scheduled).
    /// - Returns: Ids of games whose score can still change (live, or kicked off in the last 3h).
    func liveRefreshIDs() -> [String] {
        let reference = now()
        return games.filter { game in
            if let result = results[game.id] {
                return result.live
            }
            guard let kickoff = game.gameStartTime else { return false }
            let sinceKickoff = reference.timeIntervalSince(kickoff)
            return sinceKickoff >= 0 && sinceKickoff <= 3 * 3600
        }
        .map(\.id)
    }
}

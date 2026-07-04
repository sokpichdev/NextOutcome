//
//  WorldCupHubViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import Foundation
import MarketsDomain
import SharedDomain

@MainActor
@Observable
public final class WorldCupHubViewModel {
    public enum State {
        case idle, loading, loaded, failed(String)
    }

    /// 2026 FIFA World Cup Gamma series (`/sports` → sport "fifwc"): games + player props.
    /// The tag feed adds what the series omits — tournament futures (winner, awards,
    /// groups) — and doubles as the fallback when the series lookup returns nothing.
    static let seriesID = "11433"
    static let futuresTagID = "519"
    /// The tournament-winner futures event backing the flag marquee, fetched directly —
    /// it is neither in the series nor reliably in the futures tag's top page.
    static let winnerSlug = "world-cup-winner"

    public private(set) var state: State = .idle
    public private(set) var games: [Event] = []
    public private(set) var props: [Event] = []
    public private(set) var results: [String: GameResult] = [:]
    public private(set) var winnerEvent: Event?
    public private(set) var lastUpdated: Date?
    public var selectedTab: WorldCupTab = .games
    public var selectedPropsFilter: PropsFilter = .all

    private let fetchSeriesEvents: FetchSeriesEventsUseCase
    private let fetchGameResults: FetchGameResultsUseCase
    private let fetchEvents: FetchEventsUseCase
    private let fetchEvent: FetchEventUseCase
    private let now: @Sendable () -> Date

    public init(
        fetchSeriesEvents: FetchSeriesEventsUseCase,
        fetchGameResults: FetchGameResultsUseCase,
        fetchEvents: FetchEventsUseCase,
        fetchEvent: FetchEventUseCase,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fetchSeriesEvents = fetchSeriesEvents
        self.fetchGameResults = fetchGameResults
        self.fetchEvents = fetchEvents
        self.fetchEvent = fetchEvent
        self.now = now
    }

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

    public func loadIfNeeded() async {
        if case .idle = state { await load() }
    }

    public func load() async {
        state = .loading
        async let seriesFetch = fetchSeriesEvents.execute(seriesID: Self.seriesID)
        async let futuresFetch = fetchEvents.execute(tagID: Self.futuresTagID, sort: .volume24h, status: .active)
        async let winnerFetch = fetchEvent.execute(slug: Self.winnerSlug)

        let series = (try? await seriesFetch) ?? []
        let futures = (try? await futuresFetch)?.items ?? []
        let winner = try? await winnerFetch
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
        state = .loaded
        lastUpdated = now()
        await refreshResults(for: initialResultIDs())
    }

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
    func refreshResults(for eventIDs: [String]) async {
        guard !eventIDs.isEmpty else { return }
        guard let fresh = try? await fetchGameResults.execute(eventIDs: eventIDs) else { return }
        results.merge(fresh) { _, new in new }
        lastUpdated = now()
    }

    /// Games worth an initial score fetch: kickoff within ±1 day, bounded fan-out.
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

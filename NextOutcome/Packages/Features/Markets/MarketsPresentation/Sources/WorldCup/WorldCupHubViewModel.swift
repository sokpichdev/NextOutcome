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

    /// 2026 FIFA World Cup Gamma series (`/sports` → sport "fifwc"). The tag id below is
    /// the safety net when the series lookup returns nothing.
    static let seriesID = "11433"
    static let fallbackTagID = "519"

    public private(set) var state: State = .idle
    public private(set) var games: [Event] = []
    public private(set) var props: [Event] = []
    public private(set) var results: [String: GameResult] = [:]
    public private(set) var lastUpdated: Date?
    public var selectedTab: WorldCupTab = .games

    private let fetchSeriesEvents: FetchSeriesEventsUseCase
    private let fetchGameResults: FetchGameResultsUseCase
    private let fetchEvents: FetchEventsUseCase
    private let now: @Sendable () -> Date

    public init(
        fetchSeriesEvents: FetchSeriesEventsUseCase,
        fetchGameResults: FetchGameResultsUseCase,
        fetchEvents: FetchEventsUseCase,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fetchSeriesEvents = fetchSeriesEvents
        self.fetchGameResults = fetchGameResults
        self.fetchEvents = fetchEvents
        self.now = now
    }

    public var gamesByDay: [(day: Date, games: [Event])] {
        WorldCupEventSplitter.gamesByDay(games)
    }

    /// The tournament-winner futures event backing the flag marquee. Excludes award
    /// ("Golden Boot Winner") and group ("Group A Winner") events that also say "winner".
    public var winnerEvent: Event? {
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
        do {
            var events = try await fetchSeriesEvents.execute(seriesID: Self.seriesID)
            if events.isEmpty {
                events = try await fetchEvents.execute(tagID: Self.fallbackTagID, sort: .volume24h, status: .active).items
            }
            let split = WorldCupEventSplitter.split(events)
            games = split.games
            props = split.props
            state = .loaded
            lastUpdated = now()
            await refreshResults(for: initialResultIDs())
        } catch {
            state = .failed("Couldn't load World Cup markets. Pull to refresh.")
        }
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

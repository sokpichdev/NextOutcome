//
//  EsportsHubViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 14/07/2026.
//

import Foundation
import MarketsDomain

/// Drives the Esports hub: the hero carousel of live matches, the per-game tiles with
/// live counts, the Games list, and the results/price polling that keeps them current.
///
/// Live scores come from polling `/events/results` (like the World Cup hub); the
/// `LiveStatsData` Sports websocket produces the same `GameResult` shape and can replace
/// the poll later without touching this type's public surface.
@MainActor
@Observable
public final class EsportsHubViewModel {
    /// The hub's overall load state.
    public enum State: Equatable { case idle, loading, loaded, failed(String) }

    /// Which top-level tab the hub is showing (web's "Esports | Leaderboard" header).
    public enum Mode: Equatable { case esports, leaderboard }

    /// The current load state.
    public private(set) var state: State = .idle
    /// The selected top-level tab.
    public var mode: Mode = .esports
    /// The selected game filter for the Games list, or `nil` for every game.
    public var selectedGame: EsportsGame?

    /// Team-vs-team match events, live first, then soonest kickoff.
    public private(set) var matches: [Event] = []
    /// Live/final results keyed by event id, from `/events/results`.
    public private(set) var results: [String: GameResult] = [:]
    /// Recent trades keyed by event id, for the hero cards' live-trades ticker. Only hero
    /// matches are fetched, newest first.
    public private(set) var heroTrades: [String: [ActivityTrade]] = [:]
    /// Confirmed-live broadcasts keyed by event id, probed from each hero match's
    /// `resolutionSource`. Absent = offline/unknown, so the hero shows artwork.
    public private(set) var liveStreams: [String: EsportsStream] = [:]
    /// When the hub's data was last refreshed.
    public private(set) var lastUpdated: Date?

    /// The tag id `loadIfNeeded` last fetched, once known.
    private var loadedTagID: String?
    /// The results/price polling loop, while the hub is visible.
    private var pollTask: Task<Void, Never>?

    /// Loads every event under the esports tag.
    private let fetchAllEvents: FetchAllEventsUseCase
    /// Loads live scores for a batch of match events.
    private let fetchGameResults: FetchGameResultsUseCase
    /// Loads recent trades for a market condition, for the hero ticker.
    private let fetchTrades: FetchActivityTradesUseCase
    /// Probes whether hero matches' broadcasts are live. `nil` disables stream embeds.
    private let liveStreamProber: (any LiveStreamProbing)?
    /// Injectable clock for deterministic tests.
    private let now: () -> Date
    /// Seconds between result polls while visible.
    private let pollInterval: TimeInterval

    /// Creates the view model.
    /// - Parameters:
    ///   - fetchAllEvents: Loads the esports tag's events, unpaginated.
    ///   - fetchGameResults: Loads live scores for match events.
    ///   - fetchTrades: Loads recent trades for the hero cards' ticker.
    ///   - liveStreamProber: Confirms hero broadcasts are on air before embedding them.
    ///     Defaults to `nil` (no embeds), keeping tests and previews network-free.
    ///   - now: Supplies the current time. Defaults to `Date()`.
    ///   - pollInterval: Seconds between live-result refreshes. Defaults to 20.
    public init(
        fetchAllEvents: FetchAllEventsUseCase,
        fetchGameResults: FetchGameResultsUseCase,
        fetchTrades: FetchActivityTradesUseCase,
        liveStreamProber: (any LiveStreamProbing)? = nil,
        now: @escaping () -> Date = { Date() },
        pollInterval: TimeInterval = 20
    ) {
        self.fetchAllEvents = fetchAllEvents
        self.fetchGameResults = fetchGameResults
        self.fetchTrades = fetchTrades
        self.liveStreamProber = liveStreamProber
        self.now = now
        self.pollInterval = pollInterval
    }

    // MARK: - Derived collections

    /// Hero carousel pages: matches whose result says the game is live, falling back to
    /// the next few upcoming matches when nothing is live yet.
    public var heroMatches: [Event] {
        let live = matches.filter { results[$0.id]?.live == true }
        if !live.isEmpty { return live }
        // Nothing live: feature the next few matches that haven't already finished.
        return Array(matches.filter { results[$0.id]?.ended != true }.prefix(3))
    }

    /// The Games list after the `selectedGame` filter.
    public var visibleMatches: [Event] {
        guard let selectedGame else { return matches }
        return matches.filter { EsportsCatalog.game(for: $0) == selectedGame }
    }

    /// How many of a game's matches are currently live, for the tile badges.
    public func liveCount(for game: EsportsGame) -> Int {
        matches.filter { EsportsCatalog.game(for: $0) == game && results[$0.id]?.live == true }.count
    }

    /// The loaded result for an event, if any.
    public func result(for event: Event) -> GameResult? { results[event.id] }

    // MARK: - Loading

    /// Fetches the esports tag's events on first appearance, once the tag id is known
    /// (resolved at runtime by `HubTabsViewModel`, like the Crypto hub).
    public func loadIfNeeded(tagID: String) async {
        guard loadedTagID != tagID else { return }
        await load(tagID: tagID, showLoading: true)
    }

    /// Re-fetches using the last-loaded tag id (pull-to-refresh). No-op before first load.
    public func refresh() async {
        guard let tagID = loadedTagID else { return }
        await load(tagID: tagID, showLoading: false)
    }

    /// Fetches and classifies the tag's events, then loads results for near-term matches.
    private func load(tagID: String, showLoading: Bool) async {
        if showLoading { state = .loading }
        do {
            let events = try await fetchAllEvents.execute(tagID: tagID, status: .active)
            matches = Self.sortedMatches(events.filter(EsportsCatalog.isMatch), results: results, now: now())
            loadedTagID = tagID
            state = .loaded
            lastUpdated = now()
            await refreshResults()
        } catch {
            if isCancellation(error) {
                state = matches.isEmpty ? .idle : .loaded
            } else {
                state = matches.isEmpty ? .failed("Couldn't load Esports. Pull to refresh.") : .loaded
            }
        }
    }

    /// Fetches `/events/results` for matches near their start time (±6 h window keeps the
    /// batch small), then re-sorts so newly-live matches float to the top.
    public func refreshResults() async {
        let window: TimeInterval = 6 * 3600
        let reference = now()
        let nearTerm = matches.filter { match in
            guard let start = match.gameStartTime else { return true }
            return abs(start.timeIntervalSince(reference)) <= window
        }
        guard !nearTerm.isEmpty else { return }
        guard let fetched = try? await fetchGameResults.execute(eventIDs: nearTerm.map(\.id)) else { return }
        results.merge(fetched) { _, new in new }
        matches = Self.sortedMatches(matches, results: results, now: reference)
        await refreshHeroTrades()
        await refreshLiveStreams()
    }

    /// Probes each hero match's broadcast and records the ones that are actually on air.
    /// Re-runs every poll so a stream that starts (or ends) mid-session appears/disappears.
    private func refreshLiveStreams() async {
        guard let liveStreamProber else { return }
        for match in heroMatches.prefix(5) {
            guard let source = match.resolutionSource, !source.isEmpty else { continue }
            if let stream = await liveStreamProber.liveStream(for: source) {
                liveStreams[match.id] = stream
            } else {
                liveStreams[match.id] = nil
            }
        }
    }

    /// The confirmed-live broadcast for an event, if any.
    public func liveStream(for event: Event) -> EsportsStream? { liveStreams[event.id] }

    /// Fetches recent trades for each hero match's moneyline market, feeding the ticker.
    private func refreshHeroTrades() async {
        for match in heroMatches.prefix(5) {
            guard let conditionId = match.markets.first(where: { !$0.conditionId.isEmpty })?.conditionId
            else { continue }
            if let trades = try? await fetchTrades.execute(conditionId: conditionId), !trades.isEmpty {
                heroTrades[match.id] = Array(trades.prefix(10))
            }
        }
    }

    /// The hero ticker's trades for an event, newest first.
    public func trades(for event: Event) -> [ActivityTrade] { heroTrades[event.id] ?? [] }

    // MARK: - Live polling

    /// Starts the results poll while the hub is visible. Safe to call repeatedly.
    public func startLivePolling() {
        guard pollTask == nil else { return }
        let nanoseconds = UInt64(pollInterval * 1_000_000_000)
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled, let self else { return }
                await self.refreshResults()
            }
        }
    }

    /// Stops the results poll (call from `.onDisappear`).
    public func stopLivePolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Whether the polling loop is currently running (exposed for tests).
    public var isPolling: Bool { pollTask != nil }

    // MARK: - Helpers

    /// Live matches first, finished matches last, and by kickoff time (soonest first)
    /// then highest volume within each band.
    static func sortedMatches(_ matches: [Event], results: [String: GameResult], now: Date) -> [Event] {
        matches.sorted { a, b in
            let aLive = results[a.id]?.live == true
            let bLive = results[b.id]?.live == true
            if aLive != bLive { return aLive }
            let aEnded = results[a.id]?.ended == true
            let bEnded = results[b.id]?.ended == true
            if aEnded != bEnded { return bEnded }
            switch (a.gameStartTime, b.gameStartTime) {
            case let (.some(sa), .some(sb)) where sa != sb: return sa < sb
            case (.some, .none): return true
            case (.none, .some): return false
            default: return a.volume24hr > b.volume24hr
            }
        }
    }

    /// Whether `error` is a benign task/URL cancellation rather than a real failure.
    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if (error as? URLError)?.code == .cancelled { return true }
        return false
    }
}

// MARK: - Formatting

public extension EsportsHubViewModel {
    /// The payout multiplier web shows next to a team's price ("1.14x" for 88¢).
    nonisolated static func multiplier(forPrice price: Decimal) -> String? {
        guard price > 0, price <= 1 else { return nil }
        let value = 1 / NSDecimalNumber(decimal: price).doubleValue
        return String(format: "%.2fx", value)
    }

    /// A "Game 2 of 3" label from a result's `period` ("2/3"), or `nil` when unknown.
    nonisolated static func gameProgressLabel(period: String?) -> String? {
        guard let period else { return nil }
        let parts = period.split(separator: "/")
        guard parts.count == 2, let current = Int(parts[0]), let total = Int(parts[1]) else { return nil }
        return "Game \(current) of \(total)"
    }

    /// Splits a Gamma esports `score` string (`"000-000|1-0|Bo3"`) into the series score
    /// pair — the segment with a `home-away` int pair after the map-score segment.
    /// Falls back to the plain `"1-0"` shape. Returns `nil` when unparseable.
    nonisolated static func seriesScore(from score: String?) -> (home: Int, away: Int)? {
        guard let score else { return nil }
        let segments = score.split(separator: "|")
        // "000-000|1-0|Bo3" → the middle segment is the series score; plain "1-0" also works.
        let candidate = segments.count >= 2 ? segments[1] : (segments.first ?? "")
        let parts = candidate.split(separator: "-")
        guard parts.count == 2, let home = Int(parts[0]), let away = Int(parts[1]) else { return nil }
        return (home, away)
    }
}

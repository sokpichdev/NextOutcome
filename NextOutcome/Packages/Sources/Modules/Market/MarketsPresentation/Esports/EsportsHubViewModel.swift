//
//  EsportsHubViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 14/07/2026.
//

import Foundation
import MarketsDomain
import LiveStatsDomain

/// Drives the Esports hub: the hero carousel of live matches, the per-game tiles with
/// live counts, the Games list, and the results/price polling that keeps them current.
///
/// Live scores arrive two ways: the sports websocket (`SportsStateStreaming`) pushes
/// instant score/period updates for the hero matches, while the `/events/results` poll
/// (every `pollInterval`) covers the full list, supplies team metadata (logos/colours),
/// and backstops the socket across drops.
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
    /// The selected game filter for the Games list, or `nil` for every game. Set through
    /// `selectLeague(_:)`, which refetches — the filter is a server-side query now, not a
    /// predicate over whatever happens to be paged in.
    public private(set) var selectedLeague: EsportsLeague?

    /// Team-vs-team match events, live first, then soonest kickoff.
    public private(set) var matches: [Event] = []
    /// The game catalogue from Gamma `/sports`, in catalogue order.
    public private(set) var leagues: [EsportsLeague] = []
    /// The leagues worth a tile, ordered live-count then match-count descending — the tile row.
    public private(set) var visibleLeagues: [EsportsLeague] = []
    /// Which league each match belongs to, keyed by event id. Built once per data change so
    /// the tile row and every card avoid an O(matches × leagues) scan on each redraw.
    private var leagueByEventID: [String: EsportsLeague] = [:]
    /// Live match counts per league id, for the tile badges.
    private var liveCountByLeagueID: [String: Int] = [:]
    /// Ids the server returned from the in-play query, so the hub knows a match is live the
    /// moment it arrives rather than one score poll later.
    private var liveMatchIDs: Set<String> = []
    /// The keyset cursor for the next page of upcoming matches, or `nil` once exhausted.
    private var nextCursor: String?
    /// Whether another page of upcoming matches exists.
    public var hasMore: Bool { nextCursor != nil }
    /// Whether a `loadMore()` fetch is in flight — drives the list's footer spinner.
    public private(set) var isLoadingMore = false
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

    /// The tag id `loadIfNeeded` last loaded successfully, once known.
    private var loadedTagID: String?
    /// Whether a load has ever been attempted, successfully or not — what pull-to-refresh
    /// gates on, so the error state's own instruction works.
    private var hasAttemptedLoad = false
    /// The results/price polling loop, while the hub is visible.
    private var pollTask: Task<Void, Never>?

    /// Loads one page of esports matches — in-play or upcoming, futures already excluded.
    private let fetchEsportsGames: FetchEsportsGamesUseCase
    /// Loads the game catalogue behind the tile row.
    private let fetchLeagues: FetchEsportsLeaguesUseCase
    /// Loads live scores for a batch of match events.
    private let fetchGameResults: FetchGameResultsUseCase
    /// Loads recent trades for a market condition, for the hero ticker.
    private let fetchTrades: FetchActivityTradesUseCase
    /// Probes whether hero matches' broadcasts are live. `nil` disables *probing*; a live
    /// match whose URL names its video is still embedded, since that needs no network.
    private let liveStreamProber: (any LiveStreamProbing)?
    /// Streams instant score updates for hero matches. `nil` leaves the poll as the only
    /// score source (tests, previews).
    private let streamer: (any SportsStateStreaming)?
    /// Open per-match socket subscriptions, keyed by event id.
    private var socketTasks: [String: Task<Void, Never>] = [:]
    /// Injectable clock for deterministic tests.
    private let now: () -> Date
    /// Seconds between result polls while visible.
    private let pollInterval: TimeInterval

    /// Creates the view model.
    /// - Parameters:
    ///   - fetchEsportsGames: Loads a page of esports matches, in-play or upcoming.
    ///   - fetchLeagues: Loads the game catalogue behind the tile row.
    ///   - fetchGameResults: Loads live scores for match events.
    ///   - fetchTrades: Loads recent trades for the hero cards' ticker.
    ///   - liveStreamProber: Confirms hero broadcasts are on air before embedding them.
    ///     Defaults to `nil` (no embeds), keeping tests and previews network-free.
    ///   - streamer: The sports websocket, for instant hero score updates. Defaults to
    ///     `nil` (poll-only).
    ///   - now: Supplies the current time. Defaults to `Date()`.
    ///   - pollInterval: Seconds between live-result refreshes. Defaults to 20.
    public init(
        fetchEsportsGames: FetchEsportsGamesUseCase,
        fetchLeagues: FetchEsportsLeaguesUseCase,
        fetchGameResults: FetchGameResultsUseCase,
        fetchTrades: FetchActivityTradesUseCase,
        liveStreamProber: (any LiveStreamProbing)? = nil,
        streamer: (any SportsStateStreaming)? = nil,
        now: @escaping () -> Date = { Date() },
        pollInterval: TimeInterval = 20
    ) {
        self.fetchEsportsGames = fetchEsportsGames
        self.fetchLeagues = fetchLeagues
        self.fetchGameResults = fetchGameResults
        self.fetchTrades = fetchTrades
        self.liveStreamProber = liveStreamProber
        self.streamer = streamer
        self.now = now
        self.pollInterval = pollInterval
    }

    // MARK: - Derived collections

    /// Whether a match is in play: the score feed's answer when it has one, otherwise the
    /// server's — the in-play query only returns matches that are live, so a freshly-loaded
    /// hub can fill its hero carousel before the first `/events/results` poll lands.
    private func isLive(_ event: Event) -> Bool {
        Self.isLive(event.id, results: results, liveIDs: liveMatchIDs)
    }

    /// The liveness rule, free of the actor so `sortedMatches` can share it.
    nonisolated private static func isLive(
        _ eventID: String, results: [String: GameResult], liveIDs: Set<String>
    ) -> Bool {
        results[eventID]?.live ?? liveIDs.contains(eventID)
    }

    /// Hero carousel pages: the matches that are in play, falling back to the next few
    /// upcoming matches when nothing is live yet.
    public var heroMatches: [Event] {
        let live = matches.filter(isLive)
        if !live.isEmpty { return live }
        // Nothing live: feature the next few matches that haven't already finished.
        return Array(matches.filter { results[$0.id]?.ended != true }.prefix(3))
    }

    /// The Games list. The `selectedLeague` filter is applied server-side (see
    /// `selectLeague(_:)`), so everything loaded already belongs to the selection — filtering
    /// again here would only hide matches whose league tag the catalogue doesn't name.
    public var visibleMatches: [Event] { matches }

    /// How many of a league's matches are currently live, for the tile badges.
    public func liveCount(for league: EsportsLeague) -> Int {
        liveCountByLeagueID[league.id] ?? 0
    }

    /// The league a match belongs to, for its card's game caption.
    public func league(for event: Event) -> EsportsLeague? { leagueByEventID[event.id] }

    /// The loaded result for an event, if any.
    public func result(for event: Event) -> GameResult? { results[event.id] }

    /// Rebuilds the match→league index, the per-league live counts, and the tile row.
    ///
    /// Empty leagues are dropped rather than shown greyed out: the catalogue carries titles
    /// with no markets at all (PUBG, EA Sports FC, StarCraft), and a permanently dead tile is
    /// worse than a shorter row. Web ships a fixed twelve including two such tiles; this row
    /// instead tracks what's actually tradeable right now.
    ///
    /// "Tradeable" is read from the catalogue's own `activeEventCount`, not from the loaded
    /// matches, and that distinction became load-bearing when the Games list started paging:
    /// counting a paged sample would show three tiles on open and grow the row as the reader
    /// scrolled. `/sports/summary` already answers this for every game at once. Loaded matches
    /// still qualify a league on their own, so a game the summary hasn't caught up with — or a
    /// test with no activity data — keeps its tile.
    ///
    /// Live counts stay sample-derived and stay correct, because the in-play query is not
    /// paged: it returns every esports match currently in play in one request.
    private func rebuildLeagueIndex() {
        leagueByEventID = [:]
        for match in matches {
            leagueByEventID[match.id] = EsportsCatalog.league(for: match, in: leagues)
        }

        var live: [String: Int] = [:]
        var loaded: [String: Int] = [:]
        for match in matches {
            guard let league = leagueByEventID[match.id] else { continue }
            loaded[league.id, default: 0] += 1
            if isLive(match) { live[league.id, default: 0] += 1 }
        }
        liveCountByLeagueID = live

        // The catalogue's count and the loaded sample can each know something the other
        // doesn't, so a league's weight is whichever is larger.
        func weight(_ league: EsportsLeague) -> Int {
            max(league.activeEventCount, loaded[league.id] ?? 0)
        }

        visibleLeagues = leagues
            .filter { weight($0) > 0 }
            .sorted { a, b in
                let liveA = live[a.id] ?? 0, liveB = live[b.id] ?? 0
                if liveA != liveB { return liveA > liveB }
                if weight(a) != weight(b) { return weight(a) > weight(b) }
                return a.name < b.name
            }

        // A filter pinned to a league that has left the row would silently empty the list.
        if let selected = selectedLeague, !visibleLeagues.contains(selected) {
            selectedLeague = nil
        }
    }

    // MARK: - Loading

    /// Loads the hub on first appearance, once the tag id is known (resolved at runtime by
    /// `HubTabsViewModel`, like the Crypto hub).
    ///
    /// The id is the load-once key rather than a query parameter: the match query scopes
    /// itself to the esports tag server-side, the same constant the catalogue fetch uses.
    public func loadIfNeeded(tagID: String) async {
        guard loadedTagID != tagID else { return }
        hasAttemptedLoad = true
        await load(showLoading: true)
        // Recorded only on success, so a hub that failed its first load tries again when the
        // reader comes back to the tab rather than sitting on the error until they pull.
        if state == .loaded { loadedTagID = tagID }
    }

    /// Re-fetches from the first page (pull-to-refresh). No-op before the first attempt.
    ///
    /// Gated on having *attempted* a load, not having completed one: the failure state tells
    /// the reader to pull to refresh, so pulling after a failure has to actually refetch.
    public func refresh() async {
        guard hasAttemptedLoad else { return }
        await load(showLoading: false)
    }

    /// Loads the catalogue, every in-play match, and the first page of upcoming matches — all
    /// three concurrently — then fills in scores for what arrived.
    ///
    /// Two match queries rather than one, for the reason the Sports hub found: the upcoming
    /// query is bounded by kickoff, so a match already under way cannot appear in it. Asking
    /// for in-play separately also means the query is *unpaged in practice* — a handful of
    /// esports matches are ever live at once — so the hero carousel and the tile badges see
    /// the complete live set no matter how little of the upcoming feed has been scrolled.
    ///
    /// The league catalogue's failure is non-fatal: without it the tile row and the cards'
    /// game captions are absent, but the hero, the Games list and live scores all still work.
    /// Failing the whole hub over a cosmetic catalogue would be the wrong trade, and it's why
    /// there's no hardcoded fallback list — that would be the very thing this replaced,
    /// quietly drifting out of date.
    private func load(showLoading: Bool) async {
        if showLoading { state = .loading }
        nextCursor = nil
        let reference = now()
        let leagueTagID = selectedLeague?.primaryTagID

        async let catalogueTask = try? fetchLeagues.execute()
        async let liveTask = try? fetchEsportsGames.execute(
            live: true, startingAfter: nil, cursor: nil, leagueTagID: leagueTagID
        )
        async let upcomingTask = try? fetchEsportsGames.execute(
            live: false, startingAfter: reference, cursor: nil, leagueTagID: leagueTagID
        )

        // Bind before defaulting — `await x ?? []` binds as `await (x ?? [])`, which reads the
        // unresolved value rather than awaiting it.
        let loadedCatalogue = await catalogueTask
        leagues = loadedCatalogue ?? leagues
        let livePage = await liveTask
        let upcomingPage = await upcomingTask

        // Both queries down is the only outright failure; one surviving still fills the hub.
        // A cancelled task (the reader left the tab) is not a failure and must not flash an
        // error — `.task` cancels on disappear, and both fetches come back nil when it does.
        guard livePage != nil || upcomingPage != nil else {
            if Task.isCancelled {
                state = matches.isEmpty ? .idle : .loaded
            } else {
                state = matches.isEmpty ? .failed("Couldn't load Esports. Pull to refresh.") : .loaded
            }
            return
        }

        let liveEvents = livePage?.items ?? []
        liveMatchIDs = Set(liveEvents.map(\.id))
        nextCursor = upcomingPage?.nextCursor
        matches = Self.sortedMatches(
            Self.matchesOnly(liveEvents + (upcomingPage?.items ?? [])),
            results: results, liveIDs: liveMatchIDs, now: reference
        )
        rebuildLeagueIndex()
        state = .loaded
        lastUpdated = reference
        await refreshResults()
    }

    /// Loads the next page of upcoming matches onto the end of the Games list.
    ///
    /// Only the upcoming query pages. "Live now" is a complete, bounded head that refreshes
    /// with the poll rather than being re-asked on every scroll step.
    public func loadMore() async {
        guard hasMore, !isLoadingMore, state == .loaded else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        guard let page = try? await fetchEsportsGames.execute(
            live: false, startingAfter: now(), cursor: nextCursor,
            leagueTagID: selectedLeague?.primaryTagID
        ) else { return }
        nextCursor = page.nextCursor
        guard !page.items.isEmpty else { return }

        matches = Self.sortedMatches(
            Self.matchesOnly(matches + page.items),
            results: results, liveIDs: liveMatchIDs, now: now()
        )
        rebuildLeagueIndex()
        // Scores for the new page only; what's already on screen keeps the ones it has.
        await refreshResults(for: page.items)
    }

    /// Toggles the tile row's game filter and reloads scoped to it.
    ///
    /// This is a refetch, not a predicate, because the Games list is paged: filtering the
    /// loaded sample would show whichever handful of a game's matches happened to be in the
    /// first page and call it the whole list.
    /// - Parameter league: The game to filter to, or the currently-selected one to clear it.
    public func selectLeague(_ league: EsportsLeague?) async {
        let next = (league == selectedLeague) ? nil : league
        guard next != selectedLeague else { return }
        selectedLeague = next
        await load(showLoading: true)
    }

    /// Fetches `/events/results` for matches near their start time (±6 h window keeps the
    /// batch small), then re-sorts so newly-live matches float to the top.
    public func refreshResults() async {
        await refreshResults(for: matches)
    }

    /// The same refresh, narrowed to a subset — what `loadMore()` uses so a new page gets its
    /// scores without re-asking for every page already on screen.
    /// - Parameter candidates: The matches to consider; those far from kickoff are skipped.
    private func refreshResults(for candidates: [Event]) async {
        let window: TimeInterval = 6 * 3600
        let reference = now()
        let nearTerm = candidates.filter { match in
            guard let start = match.gameStartTime else { return true }
            return abs(start.timeIntervalSince(reference)) <= window
        }
        guard !nearTerm.isEmpty else { return }
        guard let fetched = try? await fetchGameResults.execute(eventIDs: nearTerm.map(\.id)) else { return }
        results.merge(fetched) { _, new in new }
        matches = Self.sortedMatches(matches, results: results, liveIDs: liveMatchIDs, now: reference)
        rebuildLeagueIndex()
        syncSocketSubscriptions()
        // Trades and broadcast probes are independent per match and independent of each
        // other, so they all go at once. Run in sequence — as they were — the hero cards
        // waited on up to ten round trips one after another before the first ticker appeared.
        async let trades: Void = refreshHeroTrades()
        async let streams: Void = refreshLiveStreams()
        _ = await (trades, streams)
    }

    // MARK: - Websocket score updates

    /// Keeps one socket subscription open per hero match (instant score/period pushes),
    /// closing subscriptions for matches that leave the hero set. Each `states(gameID:)`
    /// call owns a connection, so the set is capped to the heroes the user actually sees.
    private func syncSocketSubscriptions() {
        guard let streamer else { return }
        // Subscriptions stay keyed by event id — that's what `results` and `apply` use — but
        // they're *opened* with the feed's own `gameID`, which is what the socket keys its
        // frames on. A match with no `gameID` gets no subscription and rides the poll.
        let wanted = Dictionary(
            heroMatches.prefix(5).compactMap { match in match.gameID.map { (match.id, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        for (id, task) in socketTasks where wanted[id] == nil {
            task.cancel()
            socketTasks[id] = nil
        }
        for (eventID, gameID) in wanted where socketTasks[eventID] == nil {
            socketTasks[eventID] = Task { [weak self] in
                // The socket reconnects internally; the stream only finishes on
                // cancellation or an unrecoverable error (then the poll still covers us).
                guard let stream = self?.nonisolatedStates(streamer: streamer, gameID: gameID) else { return }
                do {
                    for try await snapshot in stream {
                        guard !Task.isCancelled, let self else { return }
                        self.apply(snapshot: snapshot, eventID: eventID)
                    }
                } catch {}
            }
        }
    }

    /// Opens the stream outside the actor hop, keeping `syncSocketSubscriptions` synchronous.
    nonisolated private func nonisolatedStates(
        streamer: any SportsStateStreaming, gameID: String
    ) -> AsyncThrowingStream<MatchState, Error> {
        streamer.states(gameID: gameID)
    }

    /// Merges a socket snapshot into `results`, preserving the poll-supplied team
    /// metadata (logos, colours, ordering) the socket doesn't carry.
    private func apply(snapshot: MatchState, eventID: String) {
        let existing = results[eventID]
        let updated = GameResult(
            eventID: eventID,
            score: snapshot.rawScore ?? existing?.score,
            elapsed: existing?.elapsed,
            period: snapshot.period ?? existing?.period,
            live: snapshot.isLive,
            ended: snapshot.ended,
            teams: existing?.teams ?? []
        )
        guard updated != existing else { return }
        results[eventID] = updated
        matches = Self.sortedMatches(matches, results: results, liveIDs: liveMatchIDs, now: now())
        rebuildLeagueIndex()
    }

    /// Resolves each hero match's broadcast and records the ones that are actually on air.
    /// Re-runs every poll so a stream that starts (or ends) mid-session appears/disappears.
    ///
    /// Two ways a match earns a player, and the gate holds in both: the score feed already
    /// says it's live, or the prober confirms the channel is on air. The first path exists
    /// because probing YouTube doesn't work — it serves our keyless fetch a bot check or a
    /// 404 — so Mobile Legends matches showed artwork while the broadcast was running. When
    /// `/events/results` says the match is live and the URL names the video, the round trip
    /// is both unreliable and redundant, so it's skipped entirely.
    private func refreshLiveStreams() async {
        let heroes = heroMatches   // snapshot: the probes await, and the set can re-sort
        var resolved: [String: EsportsStream] = [:]

        // Free path — no network, so every hero gets it however deep in the carousel.
        for match in heroes where isLive(match) {
            guard let source = match.resolutionSource, !source.isEmpty,
                  let stream = EsportsStream.embeddable(from: source) else { continue }
            resolved[match.id] = stream
        }

        // Costly path — one page fetch each, so it stays capped to the heroes a user meets
        // first. Before the free path existed this cap applied to *every* embed, which meant
        // a live match sitting 10th in a 12-match carousel could never show a player at all.
        // The five run concurrently: they're independent page fetches, and awaiting them in
        // turn made the fifth hero's player wait on the four in front of it.
        if let liveStreamProber {
            let unresolved = heroes.prefix(5).compactMap { match -> (id: String, source: String)? in
                guard resolved[match.id] == nil,
                      let source = match.resolutionSource, !source.isEmpty else { return nil }
                return (match.id, source)
            }
            let probed = await withTaskGroup(of: (String, EsportsStream?).self) { group in
                for hero in unresolved {
                    group.addTask { (hero.id, await liveStreamProber.liveStream(for: hero.source)) }
                }
                var found: [String: EsportsStream] = [:]
                for await (id, stream) in group {
                    if let stream { found[id] = stream }
                }
                return found
            }
            resolved.merge(probed) { _, new in new }
        }

        // Assigned wholesale so a broadcast that ends — or a match that leaves the hero set —
        // drops its player instead of leaving a stale one behind.
        liveStreams = resolved
    }

    /// The confirmed-live broadcast for an event, if any.
    public func liveStream(for event: Event) -> EsportsStream? { liveStreams[event.id] }

    /// Fetches recent trades for each hero match's moneyline market, feeding the ticker.
    ///
    /// Concurrently, and merged rather than assigned: a match whose fetch fails keeps the
    /// trades it already had instead of blanking its ticker.
    private func refreshHeroTrades() async {
        let wanted = heroMatches.prefix(5).compactMap { match -> (id: String, conditionId: String)? in
            guard let conditionId = match.markets.first(where: { !$0.conditionId.isEmpty })?.conditionId
            else { return nil }
            return (match.id, conditionId)
        }
        guard !wanted.isEmpty else { return }

        let fetchTrades = self.fetchTrades
        let fetched = await withTaskGroup(of: (String, [ActivityTrade]).self) { group in
            for hero in wanted {
                group.addTask {
                    let trades = (try? await fetchTrades.execute(conditionId: hero.conditionId)) ?? []
                    return (hero.id, Array(trades.prefix(10)))
                }
            }
            var found: [String: [ActivityTrade]] = [:]
            for await (id, trades) in group where !trades.isEmpty { found[id] = trades }
            return found
        }
        heroTrades.merge(fetched) { _, new in new }
    }

    /// The hero ticker's trades for an event, newest first.
    public func trades(for event: Event) -> [ActivityTrade] { heroTrades[event.id] ?? [] }

    // MARK: - Live polling

    /// Starts the results poll and hero socket subscriptions while the hub is visible.
    /// Safe to call repeatedly.
    public func startLivePolling() {
        syncSocketSubscriptions()
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

    /// Stops the results poll and closes all socket subscriptions (call from `.onDisappear`).
    public func stopLivePolling() {
        pollTask?.cancel()
        pollTask = nil
        for task in socketTasks.values { task.cancel() }
        socketTasks = [:]
    }

    /// Whether the polling loop is currently running (exposed for tests).
    public var isPolling: Bool { pollTask != nil }

    // MARK: - Helpers

    /// Keeps only team-vs-team matches, and only one copy of each.
    ///
    /// The query already asks the server for the Games tag, so this drops nothing on a normal
    /// response — it's kept because the classification is cheap over a page and the Games list
    /// showing a season future would be a visible bug, where an extra predicate is not.
    ///
    /// Deduplication earns its place for a sharper reason: the in-play and upcoming queries are
    /// separate requests against a feed that moves between them, so a match that goes live
    /// mid-load genuinely lands in both. Live is fetched first, so first-wins keeps the copy
    /// the hub already knows is in play.
    static func matchesOnly(_ events: [Event]) -> [Event] {
        var seen: Set<String> = []
        return events.filter { EsportsCatalog.isMatch($0) && seen.insert($0.id).inserted }
    }

    /// Live matches first, finished matches last, and by kickoff time (soonest first)
    /// then highest volume within each band.
    static func sortedMatches(
        _ matches: [Event], results: [String: GameResult], liveIDs: Set<String>, now: Date
    ) -> [Event] {
        matches.sorted { a, b in
            let aLive = isLive(a.id, results: results, liveIDs: liveIDs)
            let bLive = isLive(b.id, results: results, liveIDs: liveIDs)
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
        EsportsMatchProgress.parse(period).map { "Game \($0.currentMap) of \($0.totalMaps)" }
    }

    /// The series score (maps won) from a Gamma esports `score` string, or `nil` when
    /// unparseable. See `EsportsSeriesScore` for the wire format.
    nonisolated static func seriesScore(from score: String?) -> (home: Int, away: Int)? {
        EsportsSeriesScore.parse(score)?.seriesScore.map { ($0.home, $0.away) }
    }
}

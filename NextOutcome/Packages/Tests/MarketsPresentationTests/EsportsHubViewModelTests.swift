//
//  EsportsHubViewModelTests.swift
//  NextOutcome
//

import XCTest
import Foundation
import SharedDomain
@testable import MarketsPresentation
import MarketsDomain
import LiveStatsDomain

@MainActor
final class EsportsHubViewModelTests: XCTestCase {
    private func tag(_ slug: String) -> Tag { Tag(id: slug, label: slug, slug: slug) }

    private func moneyline(_ id: String) -> Market {
        Market(
            id: id, question: id, slug: id,
            outcomes: [Outcome(id: "\(id)-0", title: "A", price: 0.88), Outcome(id: "\(id)-1", title: "B", price: 0.13)],
            volume: 0, liquidity: 0, endDate: nil, isResolved: false,
            imageURL: nil, sportsMarketType: "child_moneyline"
        )
    }

    /// A match event. `gameID` deliberately differs from `id` — the sports feed keys its
    /// frames on the former, and conflating the two is exactly the bug these tests guard.
    private func match(
        _ id: String, game: String, start: Date? = nil, volume24hr: Decimal = 0,
        gameID: String? = nil
    ) -> Event {
        Event(
            id: id, title: "\(id) A vs B", slug: id, markets: [moneyline("\(id)-m")],
            volume: 0, imageURL: nil, tags: [tag("esports"), tag("games"), tag(game)],
            gameStartTime: start, volume24hr: volume24hr, gameID: gameID ?? "feed-\(id)"
        )
    }

    private func futures(_ id: String) -> Event {
        Event(id: id, title: "LCK 2026 Season Winner", slug: id, markets: [], volume: 0,
              imageURL: nil, tags: [tag("esports"), tag("league-of-legends")])
    }

    private func result(_ eventID: String, live: Bool, score: String? = nil) -> GameResult {
        GameResult(eventID: eventID, score: score, elapsed: nil, period: "2/3", live: live,
                   ended: false, teams: [])
    }

    /// The catalogue these tests classify against. `tag(_:)` sets id == slug, so a league's
    /// `primaryTagID` is the same string the `match(_:game:)` helper tags an event with.
    nonisolated private static let catalogue: [EsportsLeague] = [
        EsportsLeague(id: "cs2", name: "CS2", primaryTagID: "counter-strike-2"),
        EsportsLeague(id: "lol", name: "LoL", primaryTagID: "league-of-legends"),
        EsportsLeague(id: "dota2", name: "Dota 2", primaryTagID: "dota-2"),
        EsportsLeague(id: "pubg", name: "PUBG", primaryTagID: "pubg"),
    ]
    private func league(_ id: String) -> EsportsLeague {
        Self.catalogue.first { $0.id == id }!
    }

    private func makeVM(
        events: [Event],
        results: [String: GameResult] = [:],
        leagues: [EsportsLeague] = EsportsHubViewModelTests.catalogue,
        now: Date = .init()
    ) -> (EsportsHubViewModel, EsportsFakeRepository) {
        let repo = EsportsFakeRepository(allEvents: events, gameResults: results, leagues: leagues)
        let vm = EsportsHubViewModel(
            fetchAllEvents: FetchAllEventsUseCase(repository: repo),
            fetchLeagues: FetchEsportsLeaguesUseCase(repository: repo),
            fetchGameResults: FetchGameResultsUseCase(repository: repo),
            fetchTrades: FetchActivityTradesUseCase(repository: repo),
            now: { now },
            pollInterval: 0.05
        )
        return (vm, repo)
    }

    func test_load_keepsMatchesDropsFutures() async {
        let (vm, _) = makeVM(events: [match("m1", game: "counter-strike-2"), futures("f1")])
        await vm.loadIfNeeded(tagID: "64")
        XCTAssertEqual(vm.state, .loaded)
        XCTAssertEqual(vm.matches.map(\.id), ["m1"])
    }

    func test_loadIfNeeded_noRefetchForSameTag() async {
        let (vm, repo) = makeVM(events: [match("m1", game: "dota-2")])
        await vm.loadIfNeeded(tagID: "64")
        await vm.loadIfNeeded(tagID: "64")
        XCTAssertEqual(repo.fetchAllCallCount, 1)
    }

    func test_liveMatchesSortFirst_andFeedHero() async {
        let now = Date()
        let live = match("live", game: "dota-2", start: now.addingTimeInterval(-1800))
        let upcoming = match("up", game: "counter-strike-2", start: now.addingTimeInterval(-3600))
        let (vm, _) = makeVM(
            events: [upcoming, live],
            results: ["live": result("live", live: true)],
            now: now
        )
        await vm.loadIfNeeded(tagID: "64")
        XCTAssertEqual(vm.matches.first?.id, "live")
        XCTAssertEqual(vm.heroMatches.map(\.id), ["live"])
    }

    func test_heroFallsBackToUpcomingWhenNothingLive() async {
        let now = Date()
        let events = (0..<5).map { match("m\($0)", game: "dota-2", start: now.addingTimeInterval(Double($0) * 60)) }
        let (vm, _) = makeVM(events: events, now: now)
        await vm.loadIfNeeded(tagID: "64")
        XCTAssertEqual(vm.heroMatches.count, 3)
        XCTAssertEqual(vm.heroMatches.first?.id, "m0")
    }

    func test_gameFilterAndLiveCounts() async {
        let now = Date()
        let cs = match("cs", game: "counter-strike-2", start: now)
        let lol = match("lol", game: "league-of-legends", start: now)
        let (vm, _) = makeVM(events: [cs, lol], results: ["cs": result("cs", live: true)], now: now)
        await vm.loadIfNeeded(tagID: "64")
        vm.selectedLeague = league("cs2")
        XCTAssertEqual(vm.visibleMatches.map(\.id), ["cs"])
        XCTAssertEqual(vm.liveCount(for: league("cs2")), 1)
        XCTAssertEqual(vm.liveCount(for: league("lol")), 0)
    }

    // MARK: the tile row

    func test_tileRow_dropsLeaguesWithNoMatches() async {
        // The catalogue ships titles with no markets at all (PUBG, EA Sports FC, StarCraft).
        // Web renders those as permanently dead tiles; we don't.
        let (vm, _) = makeVM(events: [match("cs", game: "counter-strike-2")])
        await vm.loadIfNeeded(tagID: "64")
        XCTAssertEqual(vm.leagues.count, 4)
        XCTAssertEqual(vm.visibleLeagues.map(\.id), ["cs2"])
    }

    func test_tileRow_ordersByLiveThenMatchCount() async {
        let now = Date()
        let events = [
            match("lol1", game: "league-of-legends", start: now),
            match("lol2", game: "league-of-legends", start: now),
            match("dota", game: "dota-2", start: now),
            match("cs", game: "counter-strike-2", start: now),
        ]
        let (vm, _) = makeVM(events: events, results: ["dota": result("dota", live: true)], now: now)
        await vm.loadIfNeeded(tagID: "64")

        // Dota leads on one live match; LoL beats CS2 on match count with none live.
        XCTAssertEqual(vm.visibleLeagues.map(\.id), ["dota2", "lol", "cs2"])
    }

    func test_tileRow_clearsFilterWhenItsLeagueLeavesTheRow() async {
        // A filter pinned to a league that lost its last match would silently show an empty
        // Games list with no visible cause.
        let (vm, _) = makeVM(events: [match("cs", game: "counter-strike-2")])
        await vm.loadIfNeeded(tagID: "64")
        vm.selectedLeague = league("pubg")   // never in the row: no matches
        await vm.refreshResults()
        XCTAssertNil(vm.selectedLeague)
    }

    func test_load_survivesCatalogueFailure() async {
        // Losing the catalogue costs tiles and game captions; the hub itself still works.
        let repo = EsportsFakeRepository(
            allEvents: [match("cs", game: "counter-strike-2")], gameResults: [:],
            leagues: [], failLeagues: true
        )
        let vm = EsportsHubViewModel(
            fetchAllEvents: FetchAllEventsUseCase(repository: repo),
            fetchLeagues: FetchEsportsLeaguesUseCase(repository: repo),
            fetchGameResults: FetchGameResultsUseCase(repository: repo),
            fetchTrades: FetchActivityTradesUseCase(repository: repo)
        )
        await vm.loadIfNeeded(tagID: "64")

        XCTAssertEqual(vm.state, .loaded)
        XCTAssertEqual(vm.matches.map(\.id), ["cs"])
        XCTAssertTrue(vm.visibleLeagues.isEmpty)
    }

    func test_liveStreamProbe_populatesConfirmedStreamsOnly() async {
        let now = Date()
        var live = match("live", game: "counter-strike-2", start: now)
        live = Event(
            id: live.id, title: live.title, slug: live.slug, markets: live.markets,
            volume: 0, imageURL: nil, tags: live.tags, gameStartTime: now,
            resolutionSource: "https://www.twitch.tv/eslcs"
        )
        let repo = EsportsFakeRepository(allEvents: [live], gameResults: ["live": result("live", live: true)])
        let prober = FakeProber(streams: ["https://www.twitch.tv/eslcs": .twitch(channel: "eslcs")])
        let vm = EsportsHubViewModel(
            fetchAllEvents: FetchAllEventsUseCase(repository: repo),
            fetchLeagues: FetchEsportsLeaguesUseCase(repository: repo),
            fetchGameResults: FetchGameResultsUseCase(repository: repo),
            fetchTrades: FetchActivityTradesUseCase(repository: repo),
            liveStreamProber: prober,
            now: { now }
        )
        await vm.loadIfNeeded(tagID: "64")
        XCTAssertEqual(vm.liveStream(for: live), .twitch(channel: "eslcs"))
    }

    func test_liveMatchEmbedsFromTheURLWhenTheProbeFails() async {
        // MLBB points every match at YouTube, which answers our keyless page fetch with a
        // bot check or a 404 — so the probe can never confirm liveness there. When the score
        // feed already says the match is live and the URL names the video outright, that
        // probe has nothing to add.
        let now = Date()
        var m = match("live", game: "mobile-legends-bang-bang", start: now)
        m = Event(
            id: m.id, title: m.title, slug: m.slug, markets: m.markets,
            volume: 0, imageURL: nil, tags: m.tags, gameStartTime: now,
            resolutionSource: "https://www.youtube.com/watch?v=zbEa-ffJs0w"
        )
        let repo = EsportsFakeRepository(allEvents: [m], gameResults: ["live": result("live", live: true)])
        let vm = EsportsHubViewModel(
            fetchAllEvents: FetchAllEventsUseCase(repository: repo),
            fetchLeagues: FetchEsportsLeaguesUseCase(repository: repo),
            fetchGameResults: FetchGameResultsUseCase(repository: repo),
            fetchTrades: FetchActivityTradesUseCase(repository: repo),
            liveStreamProber: FakeProber(streams: [:]),   // probe fails, as it does live
            now: { now }
        )
        await vm.loadIfNeeded(tagID: "64")

        XCTAssertEqual(vm.liveStream(for: m), .youtube(videoID: "zbEa-ffJs0w"))
    }

    func test_offlineMatchStillNeedsTheProbe() async {
        // The gate stays for everything else: a match that isn't live must not open a player
        // on a finished broadcast just because its URL names a video.
        let now = Date()
        var m = match("m1", game: "mobile-legends-bang-bang", start: now)
        m = Event(
            id: m.id, title: m.title, slug: m.slug, markets: m.markets,
            volume: 0, imageURL: nil, tags: m.tags, gameStartTime: now,
            resolutionSource: "https://www.youtube.com/watch?v=zbEa-ffJs0w"
        )
        let repo = EsportsFakeRepository(allEvents: [m], gameResults: ["m1": result("m1", live: false)])
        let vm = EsportsHubViewModel(
            fetchAllEvents: FetchAllEventsUseCase(repository: repo),
            fetchLeagues: FetchEsportsLeaguesUseCase(repository: repo),
            fetchGameResults: FetchGameResultsUseCase(repository: repo),
            fetchTrades: FetchActivityTradesUseCase(repository: repo),
            liveStreamProber: FakeProber(streams: [:]),
            now: { now }
        )
        await vm.loadIfNeeded(tagID: "64")

        XCTAssertNil(vm.liveStream(for: m))
    }

    func test_liveMatchDeepInTheCarouselStillEmbeds() async {
        // Found on live data: 12 matches were live at once and Mobile Legends sat 11th, past
        // the probe's `prefix(5)` cap — so it could never show a player, fix or no fix. The
        // cap belongs to the fetch, not to the free URL-derived embed.
        let now = Date()
        func youTubeMatch(_ id: String, minutesAgo: Int, videoID: String) -> Event {
            let base = match(id, game: "mobile-legends-bang-bang")
            return Event(
                id: base.id, title: base.title, slug: base.slug, markets: base.markets,
                volume: 0, imageURL: nil, tags: base.tags,
                gameStartTime: now.addingTimeInterval(Double(-minutesAgo) * 60),
                resolutionSource: "https://www.youtube.com/watch?v=\(videoID)"
            )
        }
        // Ten matches, all live; the one we care about starts last, so it sorts last.
        let events = (0..<10).map { youTubeMatch("m\($0)", minutesAgo: 10 - $0, videoID: "vid\($0)") }
        let results = Dictionary(uniqueKeysWithValues: events.map { ($0.id, result($0.id, live: true)) })
        let repo = EsportsFakeRepository(allEvents: events, gameResults: results)
        let vm = EsportsHubViewModel(
            fetchAllEvents: FetchAllEventsUseCase(repository: repo),
            fetchLeagues: FetchEsportsLeaguesUseCase(repository: repo),
            fetchGameResults: FetchGameResultsUseCase(repository: repo),
            fetchTrades: FetchActivityTradesUseCase(repository: repo),
            liveStreamProber: FakeProber(streams: [:]),
            now: { now }
        )
        await vm.loadIfNeeded(tagID: "64")

        XCTAssertEqual(vm.heroMatches.count, 10)
        let last = try? XCTUnwrap(vm.heroMatches.last)
        XCTAssertEqual(vm.heroMatches.firstIndex(of: last ?? events[0]), 9)
        XCTAssertEqual(vm.liveStream(for: last ?? events[0]), .youtube(videoID: "vid9"))
    }

    func test_streamIsDroppedWhenTheMatchStopsBeingLive() async {
        let now = Date()
        var m = match("m1", game: "mobile-legends-bang-bang", start: now)
        m = Event(
            id: m.id, title: m.title, slug: m.slug, markets: m.markets,
            volume: 0, imageURL: nil, tags: m.tags, gameStartTime: now,
            resolutionSource: "https://www.youtube.com/watch?v=zbEa-ffJs0w"
        )
        let repo = EsportsFakeRepository(allEvents: [m], gameResults: ["m1": result("m1", live: true)])
        let vm = EsportsHubViewModel(
            fetchAllEvents: FetchAllEventsUseCase(repository: repo),
            fetchLeagues: FetchEsportsLeaguesUseCase(repository: repo),
            fetchGameResults: FetchGameResultsUseCase(repository: repo),
            fetchTrades: FetchActivityTradesUseCase(repository: repo),
            now: { now }
        )
        await vm.loadIfNeeded(tagID: "64")
        XCTAssertNotNil(vm.liveStream(for: m))

        // The broadcast ends: the player must go, not linger on a finished stream.
        repo.setResults(["m1": result("m1", live: false)])
        await vm.refreshResults()

        XCTAssertNil(vm.liveStream(for: m))
    }

    func test_offlineBroadcastYieldsNoStream() async {
        let now = Date()
        var m = match("m1", game: "dota-2", start: now)
        m = Event(
            id: m.id, title: m.title, slug: m.slug, markets: m.markets,
            volume: 0, imageURL: nil, tags: m.tags, gameStartTime: now,
            resolutionSource: "https://www.twitch.tv/offlinechannel"
        )
        let repo = EsportsFakeRepository(allEvents: [m])
        let vm = EsportsHubViewModel(
            fetchAllEvents: FetchAllEventsUseCase(repository: repo),
            fetchLeagues: FetchEsportsLeaguesUseCase(repository: repo),
            fetchGameResults: FetchGameResultsUseCase(repository: repo),
            fetchTrades: FetchActivityTradesUseCase(repository: repo),
            liveStreamProber: FakeProber(streams: [:]),
            now: { now }
        )
        await vm.loadIfNeeded(tagID: "64")
        XCTAssertNil(vm.liveStream(for: m))
    }

    func test_socketSnapshot_updatesResultInstantly_keepingPolledTeams() async {
        let now = Date()
        let live = match("live", game: "counter-strike-2", start: now)
        let polled = GameResult(
            eventID: "live", score: "000-000|0-0|Bo3", elapsed: nil, period: "1/3",
            live: true, ended: false,
            teams: [GameTeam(name: "QUAZAR", abbreviation: "qua", logoURL: nil, colorHex: "#df013c", ordering: "home")]
        )
        let repo = EsportsFakeRepository(allEvents: [live], gameResults: ["live": polled])
        let streamer = FakeStreamer()
        let vm = EsportsHubViewModel(
            fetchAllEvents: FetchAllEventsUseCase(repository: repo),
            fetchLeagues: FetchEsportsLeaguesUseCase(repository: repo),
            fetchGameResults: FetchGameResultsUseCase(repository: repo),
            fetchTrades: FetchActivityTradesUseCase(repository: repo),
            streamer: streamer,
            now: { now }
        )
        await vm.loadIfNeeded(tagID: "64")

        // Wait for the subscription task to register with the fake socket. It must subscribe
        // with the feed's `gameID`, not the Gamma event id — the socket keys frames on the
        // former, so subscribing with "live" would match nothing on the real feed.
        for _ in 0..<200 where !streamer.hasSubscriber(gameID: "feed-live") {
            await Task.yield()
        }
        XCTAssertTrue(streamer.hasSubscriber(gameID: "feed-live"))
        XCTAssertFalse(streamer.hasSubscriber(gameID: "live"), "must not subscribe with the event id")

        // Push a socket snapshot with a new series score and period.
        streamer.push(
            gameID: "feed-live",
            state: MatchState(gameID: "feed-live", rawScore: "000-000|1-0|Bo3", period: "2/3", isLive: true, ended: false)
        )
        // Give the subscription task a beat to deliver on the main actor.
        for _ in 0..<200 where vm.result(for: live)?.score != "000-000|1-0|Bo3" {
            await Task.yield()
        }

        let updated = vm.result(for: live)
        XCTAssertEqual(updated?.score, "000-000|1-0|Bo3")
        XCTAssertEqual(updated?.period, "2/3")
        XCTAssertEqual(updated?.teams.first?.name, "QUAZAR") // poll metadata preserved

        vm.stopLivePolling()
        XCTAssertTrue(streamer.cancelledGameIDs.contains("feed-live"))
    }

    func test_matchWithoutAGameID_opensNoSubscription_andStillPolls() async {
        // Not every event carries the feed's id. That must cost the match its socket, not
        // its scores — the poll stays the source of truth, which is the old behaviour.
        let now = Date()
        let noFeedID = Event(
            id: "live", title: "live A vs B", slug: "live", markets: [moneyline("live-m")],
            volume: 0, imageURL: nil,
            tags: [tag("esports"), tag("games"), tag("counter-strike-2")],
            gameStartTime: now, gameID: nil
        )
        let polled = GameResult(eventID: "live", score: "000-000|1-0|Bo3", elapsed: nil,
                                period: "2/3", live: true, ended: false, teams: [])
        let repo = EsportsFakeRepository(allEvents: [noFeedID], gameResults: ["live": polled])
        let streamer = FakeStreamer()
        let vm = EsportsHubViewModel(
            fetchAllEvents: FetchAllEventsUseCase(repository: repo),
            fetchLeagues: FetchEsportsLeaguesUseCase(repository: repo),
            fetchGameResults: FetchGameResultsUseCase(repository: repo),
            fetchTrades: FetchActivityTradesUseCase(repository: repo),
            streamer: streamer,
            now: { now }
        )
        await vm.loadIfNeeded(tagID: "64")

        XCTAssertFalse(streamer.hasSubscriber(gameID: "live"))
        XCTAssertEqual(vm.result(for: noFeedID)?.score, "000-000|1-0|Bo3")
        vm.stopLivePolling()
    }

    func test_pollingLifecycle() async {
        let (vm, _) = makeVM(events: [match("m1", game: "dota-2", start: .init())])
        await vm.loadIfNeeded(tagID: "64")
        vm.startLivePolling()
        XCTAssertTrue(vm.isPolling)
        vm.startLivePolling() // idempotent
        vm.stopLivePolling()
        XCTAssertFalse(vm.isPolling)
    }

    // MARK: formatting

    func test_multiplier() {
        XCTAssertEqual(EsportsHubViewModel.multiplier(forPrice: 0.88), "1.14x")
        XCTAssertEqual(EsportsHubViewModel.multiplier(forPrice: 0.13), "7.69x")
        XCTAssertNil(EsportsHubViewModel.multiplier(forPrice: 0))
    }

    func test_gameProgressLabel() {
        XCTAssertEqual(EsportsHubViewModel.gameProgressLabel(period: "2/3"), "Game 2 of 3")
        XCTAssertNil(EsportsHubViewModel.gameProgressLabel(period: "2H"))
        XCTAssertNil(EsportsHubViewModel.gameProgressLabel(period: nil))
    }

    func test_seriesScore() {
        XCTAssertEqual(EsportsHubViewModel.seriesScore(from: "000-000|1-0|Bo3")?.home, 1)
        XCTAssertEqual(EsportsHubViewModel.seriesScore(from: "000-000|1-0|Bo3")?.away, 0)
        XCTAssertEqual(EsportsHubViewModel.seriesScore(from: "2-1")?.home, 2)
        XCTAssertNil(EsportsHubViewModel.seriesScore(from: nil))
        XCTAssertNil(EsportsHubViewModel.seriesScore(from: "Bo3"))
    }
}

/// Hand-driven sports socket: tests push `MatchState` snapshots into per-game streams.
private final class FakeStreamer: SportsStateStreaming, @unchecked Sendable {
    private var continuations: [String: AsyncThrowingStream<MatchState, Error>.Continuation] = [:]
    private(set) var cancelledGameIDs: Set<String> = []

    func states(gameID: String) -> AsyncThrowingStream<MatchState, Error> {
        AsyncThrowingStream { continuation in
            continuations[gameID] = continuation
            continuation.onTermination = { [weak self] _ in
                self?.cancelledGameIDs.insert(gameID)
            }
        }
    }

    func push(gameID: String, state: MatchState) {
        continuations[gameID]?.yield(state)
    }

    func hasSubscriber(gameID: String) -> Bool {
        continuations[gameID] != nil
    }
}

/// Resolves canned stream URLs to live streams.
private struct FakeProber: LiveStreamProbing {
    let streams: [String: EsportsStream]
    func liveStream(for resolutionSource: String) async -> EsportsStream? {
        streams[resolutionSource]
    }
}

/// Serves canned esports events and game results to the hub view model.
private final class EsportsFakeRepository: MarketRepository, @unchecked Sendable {
    private let allEvents: [Event]
    private var gameResults: [String: GameResult]
    private let leagues: [EsportsLeague]
    private let failLeagues: Bool
    private(set) var fetchAllCallCount = 0

    init(
        allEvents: [Event],
        gameResults: [String: GameResult] = [:],
        leagues: [EsportsLeague] = [],
        failLeagues: Bool = false
    ) {
        self.allEvents = allEvents
        self.gameResults = gameResults
        self.leagues = leagues
        self.failLeagues = failLeagues
    }

    func fetchAllEvents(tagID: String, status: EventStatus) async throws -> [Event] {
        fetchAllCallCount += 1
        return allEvents
    }
    /// Swaps the canned results, so a test can end a broadcast mid-session.
    func setResults(_ results: [String: GameResult]) { gameResults = results }

    func fetchLeagues(tagID: String) async throws -> [EsportsLeague] {
        if failLeagues { throw URLError(.badServerResponse) }
        return leagues
    }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] {
        gameResults.filter { eventIDs.contains($0.key) }
    }
    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> {
        Page(items: [], nextCursor: nil)
    }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchEvent(slug: String) async throws -> Event { fatalError("unused") }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
}

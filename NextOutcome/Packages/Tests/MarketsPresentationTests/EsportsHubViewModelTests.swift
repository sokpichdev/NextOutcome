//
//  EsportsHubViewModelTests.swift
//  NextOutcome
//

import XCTest
import SharedDomain
@testable import MarketsPresentation
import MarketsDomain

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

    private func match(
        _ id: String, game: String, start: Date? = nil, volume24hr: Decimal = 0
    ) -> Event {
        Event(
            id: id, title: "\(id) A vs B", slug: id, markets: [moneyline("\(id)-m")],
            volume: 0, imageURL: nil, tags: [tag("esports"), tag("games"), tag(game)],
            gameStartTime: start, volume24hr: volume24hr
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

    private func makeVM(
        events: [Event], results: [String: GameResult] = [:], now: Date = .init()
    ) -> (EsportsHubViewModel, EsportsFakeRepository) {
        let repo = EsportsFakeRepository(allEvents: events, gameResults: results)
        let vm = EsportsHubViewModel(
            fetchAllEvents: FetchAllEventsUseCase(repository: repo),
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
        vm.selectedGame = .cs2
        XCTAssertEqual(vm.visibleMatches.map(\.id), ["cs"])
        XCTAssertEqual(vm.liveCount(for: .cs2), 1)
        XCTAssertEqual(vm.liveCount(for: .lol), 0)
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
            fetchGameResults: FetchGameResultsUseCase(repository: repo),
            fetchTrades: FetchActivityTradesUseCase(repository: repo),
            liveStreamProber: prober,
            now: { now }
        )
        await vm.loadIfNeeded(tagID: "64")
        XCTAssertEqual(vm.liveStream(for: live), .twitch(channel: "eslcs"))
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
            fetchGameResults: FetchGameResultsUseCase(repository: repo),
            fetchTrades: FetchActivityTradesUseCase(repository: repo),
            liveStreamProber: FakeProber(streams: [:]),
            now: { now }
        )
        await vm.loadIfNeeded(tagID: "64")
        XCTAssertNil(vm.liveStream(for: m))
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
    private let gameResults: [String: GameResult]
    private(set) var fetchAllCallCount = 0

    init(allEvents: [Event], gameResults: [String: GameResult] = [:]) {
        self.allEvents = allEvents
        self.gameResults = gameResults
    }

    func fetchAllEvents(tagID: String, status: EventStatus) async throws -> [Event] {
        fetchAllCallCount += 1
        return allEvents
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

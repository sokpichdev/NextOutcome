//
//  EsportsMatchDetailViewModelTests.swift
//  NextOutcome
//

import XCTest
import Foundation
import SharedDomain
@testable import MarketsPresentation
import MarketsDomain
import LiveStatsDomain

@MainActor
final class EsportsMatchDetailViewModelTests: XCTestCase {

    // MARK: - Fixtures

    private func moneyline(_ id: String) -> Market {
        Market(id: id, question: "Match Winner", slug: id,
               outcomes: [Outcome(id: "h", title: "Eternal Fire Academy", price: 0.405),
                          Outcome(id: "a", title: "Vitality Academy", price: 0.595)],
               volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil,
               sportsMarketType: "moneyline", groupItemTitle: "Match Winner")
    }

    private func match(
        gameID: String? = "1616952",
        initialResult: GameResult? = nil,
        resolutionSource: String? = "https://www.twitch.tv/eslcs"
    ) -> Event {
        Event(
            id: "809989",
            title: "Counter-Strike: Eternal Fire Academy vs Vitality Academy (BO3) - EPL",
            slug: "cs-efa-vita", markets: [moneyline("m")], volume: 88_270, imageURL: nil,
            resolutionSource: resolutionSource, gameID: gameID, initialResult: initialResult
        )
    }

    private func result(score: String? = "000-000|1-1|Bo3", period: String? = "3/3",
                        live: Bool = true, ended: Bool = false,
                        teams: [GameTeam] = []) -> GameResult {
        GameResult(eventID: "809989", score: score, elapsed: nil, period: period,
                   live: live, ended: ended, teams: teams)
    }

    private func makeVM(
        event: Event? = nil,
        repo: DetailFakeRepository = DetailFakeRepository(),
        streamer: FakeStreamer? = nil,
        prober: FakeProber? = nil
    ) -> EsportsMatchDetailViewModel {
        EsportsMatchDetailViewModel(
            event: event ?? match(),
            fetchEvent: FetchEventUseCase(repository: repo),
            fetchGameResults: FetchGameResultsUseCase(repository: repo),
            liveStreamProber: prober,
            streamer: streamer,
            pollInterval: 0.01
        )
    }

    // MARK: - Seeding

    func test_seedsFromThePushedEvent_withNoNetwork() {
        // The hub already holds a complete event, so the screen must render immediately —
        // no spinner, no empty scoreboard waiting on a request.
        let seeded = result(score: "7-5|1-1|Bo3")
        let vm = makeVM(event: match(initialResult: seeded))
        XCTAssertEqual(vm.result?.score, "7-5|1-1|Bo3")
        XCTAssertEqual(vm.scoreboard.home.mapsWon, 1)
        XCTAssertTrue(vm.isLive)
    }

    func test_eventWithoutAnInlineResult_startsWithNoScore() {
        let vm = makeVM()
        XCTAssertNil(vm.result)
        XCTAssertFalse(vm.isLive)
    }

    // MARK: - Refresh

    func test_refresh_mergesThePolledResultAndTheRefreshedEvent() async {
        let repo = DetailFakeRepository(
            results: ["809989": result(score: "000-000|2-1|Bo3")],
            event: match(initialResult: nil)
        )
        let vm = makeVM(repo: repo)
        await vm.refresh()
        XCTAssertEqual(vm.result?.score, "000-000|2-1|Bo3")
        XCTAssertEqual(repo.fetchEventCallCount, 1)
    }

    func test_refresh_survivesAFailingEventFetch() async {
        // A refresh that fails must leave a working screen alone, not blank it.
        let repo = DetailFakeRepository(results: ["809989": result()], failEvent: true)
        let vm = makeVM(repo: repo)
        await vm.refresh()
        XCTAssertEqual(vm.event.id, "809989")
        XCTAssertEqual(vm.result?.period, "3/3")
    }

    // MARK: - Socket

    func test_subscribesWithTheFeedGameID_notTheEventID() async {
        let streamer = FakeStreamer()
        let vm = makeVM(streamer: streamer)
        vm.start()
        for _ in 0..<200 where !streamer.hasSubscriber(gameID: "1616952") { await Task.yield() }

        XCTAssertTrue(streamer.hasSubscriber(gameID: "1616952"))
        XCTAssertFalse(streamer.hasSubscriber(gameID: "809989"), "must not subscribe with the event id")
        vm.stop()
    }

    func test_socketSnapshot_updatesTheScoreKeepingPolledTeamMetadata() async {
        let teams = [GameTeam(name: "Eternal Fire Academy", abbreviation: "EFA", logoURL: nil,
                              colorHex: "#29447c", ordering: "home")]
        let streamer = FakeStreamer()
        let vm = makeVM(event: match(initialResult: result(score: "000-000|1-0|Bo3", teams: teams)),
                        streamer: streamer)
        vm.start()
        for _ in 0..<200 where !streamer.hasSubscriber(gameID: "1616952") { await Task.yield() }

        streamer.push(gameID: "1616952",
                      state: MatchState(gameID: "1616952", rawScore: "3-1|1-1|Bo3",
                                        period: "3/3", isLive: true, ended: false))
        for _ in 0..<200 where vm.result?.score != "3-1|1-1|Bo3" { await Task.yield() }

        XCTAssertEqual(vm.result?.score, "3-1|1-1|Bo3")
        XCTAssertEqual(vm.result?.period, "3/3")
        XCTAssertEqual(vm.result?.teams.first?.colorHex, "#29447c", "poll metadata preserved")
        vm.stop()
    }

    func test_matchWithoutAGameID_opensNoSocketButStillPolls() async {
        let streamer = FakeStreamer()
        let repo = DetailFakeRepository(results: ["809989": result()])
        let vm = makeVM(event: match(gameID: nil), repo: repo, streamer: streamer)
        vm.start()
        await vm.refresh()

        XCTAssertTrue(streamer.subscribedGameIDs.isEmpty)
        XCTAssertEqual(vm.result?.period, "3/3")
        vm.stop()
    }

    func test_endedMatch_opensNoSocket() {
        let streamer = FakeStreamer()
        let vm = makeVM(event: match(initialResult: result(live: false, ended: true)), streamer: streamer)
        vm.start()
        XCTAssertTrue(streamer.subscribedGameIDs.isEmpty)
        vm.stop()
    }

    // MARK: - Lifecycle

    func test_pollStopsOnceTheMatchEnds() async {
        // A finished match has nothing left to poll for.
        let repo = DetailFakeRepository(results: ["809989": result(live: false, ended: true)])
        let vm = makeVM(repo: repo)
        vm.start()
        XCTAssertTrue(vm.isPolling)
        await vm.refresh()
        XCTAssertFalse(vm.isPolling)
    }

    func test_stopCancelsBothThePollAndTheSocket() async {
        let streamer = FakeStreamer()
        let vm = makeVM(streamer: streamer)
        vm.start()
        for _ in 0..<200 where !streamer.hasSubscriber(gameID: "1616952") { await Task.yield() }

        vm.stop()
        XCTAssertFalse(vm.isPolling)
        for _ in 0..<200 where !streamer.cancelledGameIDs.contains("1616952") { await Task.yield() }
        XCTAssertTrue(streamer.cancelledGameIDs.contains("1616952"))
    }

    // MARK: - Broadcast

    func test_streamIsNotResolvedUntilTheLivestreamTabIsOpened() async {
        // Probing costs a page fetch; nobody pays for a tab they never open.
        let prober = FakeProber(streams: ["https://www.twitch.tv/eslcs": .twitch(channel: "eslcs")])
        let vm = makeVM(event: match(initialResult: result()), prober: prober)
        await vm.refresh()
        XCTAssertNil(vm.stream)

        await vm.requestStream()
        XCTAssertEqual(vm.stream, .twitch(channel: "eslcs"))
    }

    func test_liveMatchWhoseURLNamesItsVideoNeedsNoProbe() async {
        // The YouTube path: probing it gets us a bot check, and the id is already in the URL.
        let vm = makeVM(event: match(initialResult: result(),
                                     resolutionSource: "https://www.youtube.com/watch?v=zbEa-ffJs0w"))
        await vm.requestStream()
        XCTAssertEqual(vm.stream, .youtube(videoID: "zbEa-ffJs0w"))
    }

    func test_broadcastURL_isOfferedEvenWhenTheHostCannotEmbed() async {
        // Kick is common on esports events and has no embed case, so the screen links out.
        let vm = makeVM(event: match(initialResult: result(),
                                     resolutionSource: "https://kick.com/eplcs_en"))
        await vm.requestStream()
        XCTAssertNil(vm.stream)
        XCTAssertEqual(vm.broadcastURL, URL(string: "https://kick.com/eplcs_en"))
    }

    func test_noResolutionSource_yieldsNoStreamAndNoLink() async {
        let vm = makeVM(event: match(initialResult: result(), resolutionSource: nil))
        await vm.requestStream()
        XCTAssertNil(vm.stream)
        XCTAssertNil(vm.broadcastURL)
    }

    // MARK: - Status line

    func test_statusText_readsTheMapProgressWhileLive() {
        let vm = makeVM(event: match(initialResult: result(period: "3/3")))
        XCTAssertEqual(vm.statusText, "Map 3 of 3")
    }

    func test_statusText_saysFinalOnceEnded_neverEndedFromAStaleKickoff() {
        // The generic event screen printed "Ended" over a live match because every market's
        // gameStartTime is in the past. Status here comes from the result, so it can't.
        let ended = makeVM(event: match(initialResult: result(live: false, ended: true)))
        XCTAssertEqual(ended.statusText, "Final")

        let live = makeVM(event: match(initialResult: result(period: "2/3")))
        XCTAssertEqual(live.statusText, "Map 2 of 3")
        XCTAssertTrue(live.isLive)
    }

    // MARK: - Sections

    func test_groups_giveEsportsMarketsRealSections() {
        let vm = makeVM()
        XCTAssertEqual(vm.groups.first?.group, .moneyline)
        XCTAssertEqual(vm.moneylineMarket?.groupItemTitle, "Match Winner")
    }
}

/// Serves a canned event and game results to the match detail view model.
private final class DetailFakeRepository: MarketRepository, @unchecked Sendable {
    private let results: [String: GameResult]
    private let event: Event?
    private let failEvent: Bool
    private(set) var fetchEventCallCount = 0

    init(results: [String: GameResult] = [:], event: Event? = nil, failEvent: Bool = false) {
        self.results = results
        self.event = event
        self.failEvent = failEvent
    }

    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] {
        results.filter { eventIDs.contains($0.key) }
    }
    func fetchEvent(slug: String) async throws -> Event {
        fetchEventCallCount += 1
        if failEvent { throw URLError(.badServerResponse) }
        guard let event else { throw URLError(.badServerResponse) }
        return event
    }
    func fetchAllEvents(tagID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchLeagues(tagID: String) async throws -> [EsportsLeague] { [] }
    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> {
        Page(items: [], nextCursor: nil)
    }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
}

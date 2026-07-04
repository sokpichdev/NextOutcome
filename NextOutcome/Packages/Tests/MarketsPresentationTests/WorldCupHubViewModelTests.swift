//
//  WorldCupHubViewModelTests.swift
//  NextOutcome
//

import XCTest
import SharedDomain
@testable import MarketsPresentation
import MarketsDomain

@MainActor
final class WorldCupHubViewModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_782_216_000) // fixed clock

    private func game(_ id: String, kickoffOffset: TimeInterval, volume: Decimal = 0) -> Event {
        Event(
            id: id, title: "\(id) vs. X", slug: id,
            markets: [.init(id: "\(id)-ml", question: "\(id) winner", slug: "\(id)-ml",
                            outcomes: [], volume: 0, liquidity: 0, endDate: nil,
                            isResolved: false, imageURL: nil, sportsMarketType: "moneyline")],
            volume: volume, imageURL: nil, gameStartTime: now.addingTimeInterval(kickoffOffset)
        )
    }

    private func prop(_ id: String, title: String, volume: Decimal = 0) -> Event {
        Event(id: id, title: title, slug: id, markets: [], volume: volume, imageURL: nil)
    }

    private func makeVM(repo: WorldCupFakeRepository) -> WorldCupHubViewModel {
        WorldCupHubViewModel(
            fetchSeriesEvents: FetchSeriesEventsUseCase(repository: repo),
            fetchGameResults: FetchGameResultsUseCase(repository: repo),
            fetchEvents: FetchEventsUseCase(repository: repo),
            fetchEvent: FetchEventUseCase(repository: repo),
            fetchTeams: FetchTeamsUseCase(repository: repo),
            now: { [now] in now }
        )
    }

    func test_load_splitsGamesAndProps_andFetchesNearbyScores() async {
        let repo = WorldCupFakeRepository()
        repo.seriesEvents = [
            game("near", kickoffOffset: 3600),
            game("far", kickoffOffset: 10 * 86_400),
            prop("winner", title: "World Cup Winner"),
        ]
        repo.results = ["near": .fixture(eventID: "near", live: true)]
        let vm = makeVM(repo: repo)

        await vm.load()

        XCTAssertEqual(vm.games.map(\.id), ["near", "far"])
        XCTAssertEqual(vm.props.map(\.id), ["winner"])
        // Only the ±24h game is in the initial score fan-out.
        XCTAssertEqual(repo.requestedResultIDs, [["near"]])
        XCTAssertEqual(vm.results["near"]?.live, true)
        XCTAssertNotNil(vm.lastUpdated)
    }

    func test_load_mergesFuturesTag_dedupingSeriesEvents() async {
        let repo = WorldCupFakeRepository()
        repo.seriesEvents = [game("g1", kickoffOffset: 3600), prop("dup", title: "Shared prop")]
        repo.taggedEvents = [prop("dup", title: "Shared prop"), prop("winner", title: "World Cup Winner")]
        let vm = makeVM(repo: repo)

        await vm.load()

        XCTAssertEqual(repo.fetchedTagIDs, ["519"]) // futures fetched alongside the series
        XCTAssertEqual(vm.props.map(\.id), ["dup", "winner"]) // deduped by event id
        XCTAssertEqual(vm.winnerEvent?.id, "winner")
    }

    func test_load_fallsBackToTag_whenSeriesEmpty() async {
        let repo = WorldCupFakeRepository()
        repo.seriesEvents = []
        repo.taggedEvents = [game("g1", kickoffOffset: 3600)]
        let vm = makeVM(repo: repo)

        await vm.load()

        XCTAssertEqual(repo.fetchedTagIDs, ["519"])
        XCTAssertEqual(vm.games.map(\.id), ["g1"])
    }

    func test_winnerEvent_prefersSlugFetch() async {
        let repo = WorldCupFakeRepository()
        repo.seriesEvents = [prop("cup", title: "World Cup Winner")]
        repo.slugEvent = prop("slug-winner", title: "World Cup Winner")
        let vm = makeVM(repo: repo)
        await vm.load()
        XCTAssertEqual(repo.fetchedSlugs, ["world-cup-winner"])
        XCTAssertEqual(vm.winnerEvent?.id, "slug-winner")
    }

    func test_winnerEvent_heuristicFallback_prefersTournamentWinner_overAwardsAndGroups() async {
        let repo = WorldCupFakeRepository()
        repo.seriesEvents = [
            prop("boot", title: "World Cup: Golden Boot Winner", volume: 999),
            prop("group", title: "Group A Winner", volume: 999),
            prop("cup", title: "World Cup Winner", volume: 10),
        ]
        let vm = makeVM(repo: repo) // slugEvent nil → slug fetch throws → heuristic
        await vm.load()
        XCTAssertEqual(vm.winnerEvent?.id, "cup")
    }

    func test_liveRefreshIDs_liveGamesAndRecentKickoffsOnly() async {
        let repo = WorldCupFakeRepository()
        repo.seriesEvents = [
            game("live", kickoffOffset: -3600),      // has live result
            game("recent", kickoffOffset: -7200),    // no result yet, kicked off 2h ago
            game("done", kickoffOffset: -3600),      // result says ended
            game("upcoming", kickoffOffset: 3600),   // not started
        ]
        repo.results = [
            "live": .fixture(eventID: "live", live: true),
            "done": .fixture(eventID: "done", live: false, ended: true),
        ]
        let vm = makeVM(repo: repo)
        await vm.load()

        XCTAssertEqual(Set(vm.liveRefreshIDs()), ["live", "recent"])
    }

    func test_refreshResults_mergesKeepingExistingEntries() async {
        let repo = WorldCupFakeRepository()
        repo.seriesEvents = [game("a", kickoffOffset: 0), game("b", kickoffOffset: 90 * 86_400)]
        repo.results = ["a": .fixture(eventID: "a", live: true)]
        let vm = makeVM(repo: repo)
        await vm.load()

        repo.results = ["b": .fixture(eventID: "b", live: true)]
        await vm.refreshResults(for: ["b"])

        XCTAssertEqual(vm.results.keys.sorted(), ["a", "b"])
    }
}

private extension GameResult {
    static func fixture(eventID: String, live: Bool, ended: Bool = false) -> GameResult {
        GameResult(eventID: eventID, score: nil, elapsed: nil, period: nil,
                   live: live, ended: ended, teams: [])
    }
}

private final class WorldCupFakeRepository: MarketRepository, @unchecked Sendable {
    var seriesEvents: [Event] = []
    var taggedEvents: [Event] = []
    var slugEvent: Event?
    var results: [String: GameResult] = [:]
    private(set) var requestedResultIDs: [[String]] = []
    private(set) var fetchedTagIDs: [String?] = []
    private(set) var fetchedSlugs: [String] = []

    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { seriesEvents }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] {
        requestedResultIDs.append(eventIDs)
        return results.filter { eventIDs.contains($0.key) }
    }
    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus) async throws -> Page<Event> {
        fetchedTagIDs.append(tagID)
        return Page(items: taggedEvents, nextCursor: nil)
    }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
    func fetchEvent(slug: String) async throws -> Event {
        fetchedSlugs.append(slug)
        guard let slugEvent else { throw URLError(.resourceUnavailable) }
        return slugEvent
    }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
}

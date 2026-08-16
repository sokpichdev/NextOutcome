//
//  SportsHubViewModelTests.swift
//  NextOutcome
//

import XCTest
import Foundation
import SharedDomain
@testable import MarketsPresentation
import MarketsDomain

@MainActor
final class SportsHubViewModelTests: XCTestCase {
    private func tag(_ id: String, _ label: String) -> Tag { Tag(id: id, label: label, slug: label.lowercased()) }

    private func event(_ id: String, tags: [Tag], volume: Decimal = 0, gameStartTime: Date? = nil) -> Event {
        Event(id: id, title: id, slug: id, markets: [], volume: volume, imageURL: nil, tags: tags, gameStartTime: gameStartTime)
    }

    private func league(_ id: String, group: String?, count: Int, live: Bool = false, volume: Decimal = 0) -> SportLeague {
        SportLeague(id: id, name: id.uppercased(), primaryTagID: "tag-\(id)", groupTagID: group,
                    activeEventCount: count, hasLive: live, volume: volume)
    }

    private func makeVM(
        events: [Event], catalogue: [SportLeague] = [], now: @escaping @Sendable () -> Date = Date.init
    ) -> (SportsHubViewModel, SportsFakeRepository) {
        let repo = SportsFakeRepository(allEvents: events)
        repo.catalogue = catalogue
        let vm = SportsHubViewModel(
            fetchEvents: FetchEventsUseCase(repository: repo),
            fetchAllEvents: FetchAllEventsUseCase(repository: repo),
            fetchSportsCatalogue: FetchSportsCatalogueUseCase(repository: repo),
            fetchGameResults: FetchGameResultsUseCase(repository: repo),
            now: now
        )
        return (vm, repo)
    }

    func test_load_buildsChipsFromTheServerCatalogue_notFromEventTagKeywords() async {
        // The regression this locks in: chips used to be five hardcoded keywords matched as
        // substrings against sampled event tags, so a league only appeared if it happened to
        // be in the feed. Now the catalogue decides.
        let (vm, _) = makeVM(events: [event("e1", tags: [tag("1", "Sports")])], catalogue: [
            league("mlb", group: nil, count: 118, live: true, volume: 5_957_601),
            league("epl", group: "100350", count: 140, volume: 297_170),
        ])

        await vm.load()

        XCTAssertEqual(vm.catalogue.map(\.name), ["MLB", "Soccer"])
    }

    func test_navGroups_excludeSportsWithNoOpenEvents() async {
        let (vm, _) = makeVM(events: [event("e1", tags: [tag("1", "Sports")])], catalogue: [
            league("mlb", group: nil, count: 118, volume: 5_957_601),
            league("nhl", group: nil, count: 0, volume: 900),
        ])

        await vm.load()

        XCTAssertEqual(vm.navGroups.map(\.name), ["MLB"])
        XCTAssertEqual(vm.catalogue.count, 2, "the All Sports sheet still lists the dormant sport")
    }

    func test_load_fetchesResultsForTheLiveFeedsEvents() async {
        // gameStartTime must fall within the ±24h fetch window (Finding 2's narrowing), or the
        // event is excluded from the results fetch entirely.
        let (vm, repo) = makeVM(events: [event("g1", tags: [tag("1", "Sports")], gameStartTime: Date())])
        repo.results = ["g1": GameResult(eventID: "g1", score: "3-1", elapsed: "5:41",
                                         period: "Q4", live: true, ended: false, teams: [])]

        await vm.load()

        XCTAssertEqual(vm.results["g1"]?.period, "Q4")
    }

    func test_load_survivesCatalogueFailure() async {
        // Chips are an enhancement; the feed is the screen. A catalogue error must not blank
        // the hub.
        let (vm, repo) = makeVM(events: [event("e1", tags: [tag("1", "Sports")])])
        repo.catalogueError = true

        await vm.load()

        XCTAssertEqual(vm.state, .loaded)
        XCTAssertTrue(vm.navGroups.isEmpty)
    }

    func test_setLiveSort_soonest_reordersWithoutRefetch() async {
        let (vm, repo) = makeVM(events: [
            event("a", tags: [tag("85", "Wimbledon")], volume: 10),
            event("b", tags: [tag("85", "Wimbledon")], volume: 50),
        ])
        await vm.load()
        let fetchCountBefore = repo.fetchAllCallCount

        vm.setLiveSort(.soonest)

        XCTAssertEqual(repo.fetchAllCallCount, fetchCountBefore) // no refetch
        XCTAssertEqual(vm.liveSort, .soonest)
    }

    func test_load_noEvents_fails() async {
        let (vm, _) = makeVM(events: [])
        await vm.load()
        guard case .failed = vm.state else { return XCTFail("expected .failed, got \(vm.state)") }
    }

    func test_selectFuturesSport_reloadsFuturesEvents() async {
        // futuresSports now comes from catalogue.prefix(8), not from event tags — seed the
        // catalogue with distinct volumes so the NBA group sorts first and is auto-selected.
        let (vm, repo) = makeVM(events: [
            event("nba-sample", tags: [tag("101", "NBA")]),
            event("epl-sample", tags: [tag("102", "EPL")]),
        ], catalogue: [
            SportLeague(id: "nba", name: "NBA", primaryTagID: "101", volume: 1_000),
            SportLeague(id: "epl", name: "EPL", primaryTagID: "102", volume: 500),
        ])
        repo.futuresPages["101"] = [event("nba-champ", tags: [])]
        repo.futuresPages["102"] = [event("epl-winner", tags: [])]

        await vm.load()
        XCTAssertEqual(vm.selectedFuturesSportID, "101") // first futures sport auto-selected
        XCTAssertEqual(vm.futuresEvents.map(\.id), ["nba-champ"])

        await vm.selectFuturesSport("102")
        XCTAssertEqual(vm.futuresEvents.map(\.id), ["epl-winner"])
    }

    func test_selectFuturesSport_sameID_isNoOp() async {
        let (vm, repo) = makeVM(events: [event("nba-sample", tags: [tag("101", "NBA")])], catalogue: [
            SportLeague(id: "nba", name: "NBA", primaryTagID: "101", volume: 1_000),
        ])
        repo.futuresPages["101"] = [event("nba-champ", tags: [])]
        await vm.load()

        let fetchCountBefore = repo.futuresFetchCount
        await vm.selectFuturesSport("101")
        XCTAssertEqual(repo.futuresFetchCount, fetchCountBefore)
    }

    // MARK: SportsHubViewModel.initialResultIDs

    private static let referenceNow = Date(timeIntervalSince1970: 1_700_000_000)

    func test_initialResultIDs_excludesEventsOutsideTheWindow() {
        let now = Self.referenceNow
        let events = [
            event("inWindow", tags: [], gameStartTime: now.addingTimeInterval(3600)), // +1h
            event("outsideWindow", tags: [], gameStartTime: now.addingTimeInterval(25 * 3600)), // +25h
        ]

        XCTAssertEqual(SportsHubViewModel.initialResultIDs(from: events, now: now), ["inWindow"])
    }

    func test_initialResultIDs_excludesEventsWithNoGameStartTime() {
        let now = Self.referenceNow
        let events = [
            event("scheduled", tags: [], gameStartTime: now),
            event("notAGame", tags: []), // nil gameStartTime — not a scheduled game
        ]

        XCTAssertEqual(SportsHubViewModel.initialResultIDs(from: events, now: now), ["scheduled"])
    }

    func test_initialResultIDs_capsAtTheLimit() {
        let now = Self.referenceNow
        let events = (0..<40).map { event("e\($0)", tags: [], gameStartTime: now) }

        let ids = SportsHubViewModel.initialResultIDs(from: events, now: now, cap: 30)

        XCTAssertEqual(ids.count, 30)
    }

    func test_initialResultIDs_preservesIncomingOrder() {
        // `events` arrives volume-sorted; the narrowed list must keep that order so the
        // most-traded games win the fetch budget.
        let now = Self.referenceNow
        let events = [
            event("highestVolume", tags: [], gameStartTime: now),
            event("midVolume", tags: [], gameStartTime: now.addingTimeInterval(-3600)),
            event("lowestVolume", tags: [], gameStartTime: now.addingTimeInterval(3600)),
        ]

        XCTAssertEqual(
            SportsHubViewModel.initialResultIDs(from: events, now: now),
            ["highestVolume", "midVolume", "lowestVolume"]
        )
    }

    func test_load_fetchesResultsOnlyForTheNarrowedEventWindow() async {
        // Regression for unbounded fan-out: the full ~500-event sample must not all be passed
        // to fetchGameResults, only the ones within the window (and capped).
        let now = Self.referenceNow
        let (vm, repo) = makeVM(events: [
            event("nearKickoff", tags: [tag("1", "Sports")], gameStartTime: now.addingTimeInterval(3600)),
            event("farAway", tags: [tag("1", "Sports")], gameStartTime: now.addingTimeInterval(48 * 3600)),
            event("noKickoff", tags: [tag("1", "Sports")]),
        ], now: { now })

        await vm.load()

        XCTAssertEqual(repo.lastGameResultsEventIDs, ["nearKickoff"])
    }
}

@MainActor
final class SportsLeagueDetailViewModelTests: XCTestCase {
    private func game(_ id: String, volume: Decimal = 0) -> Event {
        Event(
            id: id, title: id, slug: id,
            markets: [.init(id: "\(id)-ml", question: id, slug: id, outcomes: [], volume: 0,
                            liquidity: 0, endDate: nil, isResolved: false, imageURL: nil,
                            sportsMarketType: "moneyline")],
            volume: volume, imageURL: nil, gameStartTime: .now
        )
    }

    private func prop(_ id: String, volume: Decimal = 0) -> Event {
        Event(id: id, title: id, slug: id, markets: [], volume: volume, imageURL: nil)
    }

    private func makeVM(repo: SportsFakeRepository, league: SportsLeague = .init(id: "85", title: "Wimbledon", glyph: "figure.tennis")) -> SportsLeagueDetailViewModel {
        SportsLeagueDetailViewModel(league: league, fetchAllEvents: FetchAllEventsUseCase(repository: repo))
    }

    func test_load_splitsIntoGamesAndProps() async {
        let repo = SportsFakeRepository(allEvents: [])
        repo.leagueEvents = [game("g1"), prop("p1")]
        let vm = makeVM(repo: repo)

        await vm.load()

        XCTAssertEqual(vm.state, .loaded)
        vm.selectedTab = .games
        XCTAssertEqual(vm.visibleEvents.map(\.id), ["g1"])
        vm.selectedTab = .props
        XCTAssertEqual(vm.visibleEvents.map(\.id), ["p1"])
    }

    func test_load_empty_fails() async {
        let repo = SportsFakeRepository(allEvents: [])
        let vm = makeVM(repo: repo)

        await vm.load()

        guard case .failed = vm.state else { return XCTFail("expected .failed, got \(vm.state)") }
    }

    func test_searchQuery_filtersVisibleEvents_caseInsensitive() async {
        let repo = SportsFakeRepository(allEvents: [])
        repo.leagueEvents = [
            Event(id: "m1", title: "Wimbledon Final", slug: "m1", markets: [], volume: 0, imageURL: nil),
            Event(id: "m2", title: "MLB Game", slug: "m2", markets: [], volume: 0, imageURL: nil),
        ]
        let vm = makeVM(repo: repo)
        await vm.load()
        vm.selectedTab = .props // these events have no kickoff/moneyline, so they're props

        vm.searchQuery = "final"
        XCTAssertEqual(vm.visibleEvents.map(\.id), ["m1"])

        vm.searchQuery = ""
        XCTAssertEqual(vm.visibleEvents.map(\.id), ["m1", "m2"])
    }

    func test_setSort_appliesToVisibleEvents() async {
        let repo = SportsFakeRepository(allEvents: [])
        repo.leagueEvents = [prop("low", volume: 5), prop("high", volume: 50)]
        let vm = makeVM(repo: repo)
        await vm.load()
        vm.selectedTab = .props

        XCTAssertEqual(vm.visibleEvents.map(\.id), ["high", "low"]) // default: volume desc
        vm.setSort(.soonest)
        XCTAssertEqual(vm.sort, .soonest)
    }

    func test_standingsEvent_isHighestVolumeProp() async {
        let repo = SportsFakeRepository(allEvents: [])
        repo.leagueEvents = [game("g1", volume: 999), prop("low", volume: 5), prop("high", volume: 50)]
        let vm = makeVM(repo: repo)
        await vm.load()

        XCTAssertEqual(vm.standingsEvent?.id, "high")
    }

    func test_standingsEvent_nilWhenNoProps() async {
        let repo = SportsFakeRepository(allEvents: [])
        repo.leagueEvents = [game("g1")]
        let vm = makeVM(repo: repo)
        await vm.load()

        XCTAssertNil(vm.standingsEvent)
    }
}

/// A fake repository serving a flat event list for the general sports tag via
/// `fetchAllEvents` (`allEvents`), per-tag futures pages (`futuresPages`, via the paged
/// `fetchEvents`), and a flat league events list (`leagueEvents`, via `fetchAllEvents` for
/// any non-sports tag) for `SportsLeagueDetailViewModel` tests.
private final class SportsFakeRepository: MarketRepository, @unchecked Sendable {
    private let allEvents: [Event]
    var futuresPages: [String: [Event]] = [:]
    var leagueEvents: [Event] = []
    private(set) var futuresFetchCount = 0
    private(set) var fetchAllCallCount = 0
    var catalogue: [SportLeague] = []
    var catalogueError = false
    var results: [String: GameResult] = [:]
    /// The ids passed to the most recent `fetchGameResults` call, for asserting fan-out is bounded.
    private(set) var lastGameResultsEventIDs: [String] = []

    init(allEvents: [Event]) { self.allEvents = allEvents }

    func fetchAllEvents(tagID: String, status: EventStatus) async throws -> [Event] {
        fetchAllCallCount += 1
        return tagID == SportsHubViewModel.sportsTagID ? allEvents : leagueEvents
    }
    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> {
        if let tagID, let futures = futuresPages[tagID] {
            futuresFetchCount += 1
            return Page(items: futures, nextCursor: nil)
        }
        return Page(items: [], nextCursor: nil)
    }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] {
        lastGameResultsEventIDs = eventIDs
        return results
    }
    func fetchSportsCatalogue() async throws -> [SportLeague] {
        if catalogueError { throw URLError(.badServerResponse) }
        return catalogue
    }
    func fetchEvent(slug: String) async throws -> Event { fatalError("unused") }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
}

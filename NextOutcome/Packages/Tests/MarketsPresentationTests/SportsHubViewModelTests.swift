//
//  SportsHubViewModelTests.swift
//  NextOutcome
//

import XCTest
import SharedDomain
@testable import MarketsPresentation
import MarketsDomain

@MainActor
final class SportsHubViewModelTests: XCTestCase {
    private func tag(_ id: String, _ label: String) -> Tag { Tag(id: id, label: label, slug: label.lowercased()) }

    private func event(_ id: String, tags: [Tag], volume: Decimal = 0) -> Event {
        Event(id: id, title: id, slug: id, markets: [], volume: volume, imageURL: nil, tags: tags)
    }

    private func makeVM(events: [Event]) -> (SportsHubViewModel, SportsFakeRepository) {
        let repo = SportsFakeRepository(allEvents: events)
        let vm = SportsHubViewModel(
            fetchEvents: FetchEventsUseCase(repository: repo),
            fetchAllEvents: FetchAllEventsUseCase(repository: repo)
        )
        return (vm, repo)
    }

    func test_load_derivesLeaguesFromSampleTags_notFromTagCatalogue() async {
        let (vm, _) = makeVM(events: [
            event("wimbledon-1", tags: [tag("1", "Sports"), tag("85", "Wimbledon")]),
            event("mlb-1", tags: [tag("1", "Sports"), tag("128", "MLB")]),
            event("wc-1", tags: [tag("1", "Sports"), tag("519", "FIFA World Cup")]),
        ])

        await vm.load()

        XCTAssertEqual(vm.leagues.map(\.title), ["World Cup", "Wimbledon", "MLB"])
        XCTAssertEqual(vm.leagues.first { $0.title == "World Cup" }?.id, "519")
    }

    func test_load_groupsEventsByLeague_dropsUnmatched_sortsByVolumeDescending() async {
        let (vm, _) = makeVM(events: [
            event("wimbledon-1", tags: [tag("85", "Wimbledon")], volume: 10),
            event("wimbledon-2", tags: [tag("85", "Wimbledon")], volume: 50),
            event("mlb-1", tags: [tag("128", "MLB")]),
            event("other", tags: [tag("999", "Chess")]),
        ])

        await vm.load()

        let groupTitles = vm.liveGroups.map(\.league.title)
        XCTAssertEqual(groupTitles, ["Wimbledon", "MLB"])
        XCTAssertEqual(vm.liveGroups.first { $0.league.title == "Wimbledon" }?.events.map(\.id), ["wimbledon-2", "wimbledon-1"])
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
        let (vm, repo) = makeVM(events: [
            event("nba-sample", tags: [tag("101", "NBA")]),
            event("epl-sample", tags: [tag("102", "EPL")]),
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
        let (vm, repo) = makeVM(events: [event("nba-sample", tags: [tag("101", "NBA")])])
        repo.futuresPages["101"] = [event("nba-champ", tags: [])]
        await vm.load()

        let fetchCountBefore = repo.futuresFetchCount
        await vm.selectFuturesSport("101")
        XCTAssertEqual(repo.futuresFetchCount, fetchCountBefore)
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
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchEvent(slug: String) async throws -> Event { fatalError("unused") }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
}

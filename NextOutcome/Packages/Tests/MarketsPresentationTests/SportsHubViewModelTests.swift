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

    private func makeVM(pages: [[Event]]) -> (SportsHubViewModel, SportsFakeRepository) {
        let repo = SportsFakeRepository(pages: pages)
        let vm = SportsHubViewModel(fetchEvents: FetchEventsUseCase(repository: repo))
        return (vm, repo)
    }

    func test_load_derivesLeaguesFromSampleTags_notFromTagCatalogue() async {
        let (vm, _) = makeVM(pages: [[
            event("wimbledon-1", tags: [tag("1", "Sports"), tag("85", "Wimbledon")]),
            event("mlb-1", tags: [tag("1", "Sports"), tag("128", "MLB")]),
            event("wc-1", tags: [tag("1", "Sports"), tag("519", "FIFA World Cup")]),
        ]])

        await vm.load()

        XCTAssertEqual(vm.leagues.map(\.title), ["World Cup", "Wimbledon", "MLB"])
        XCTAssertEqual(vm.leagues.first { $0.title == "World Cup" }?.id, "519")
    }

    func test_load_groupsEventsByLeague_dropsUnmatched() async {
        let (vm, _) = makeVM(pages: [[
            event("wimbledon-1", tags: [tag("85", "Wimbledon")]),
            event("wimbledon-2", tags: [tag("85", "Wimbledon")]),
            event("mlb-1", tags: [tag("128", "MLB")]),
            event("other", tags: [tag("999", "Chess")]),
        ]])

        await vm.load()

        let groupTitles = vm.liveGroups.map(\.league.title)
        XCTAssertEqual(groupTitles, ["Wimbledon", "MLB"])
        XCTAssertEqual(vm.liveGroups.first { $0.league.title == "Wimbledon" }?.events.map(\.id), ["wimbledon-1", "wimbledon-2"])
    }

    func test_load_paginatesUpToCap_stopsWhenPageEmpty() async {
        let (vm, repo) = makeVM(pages: [
            [event("a1", tags: [tag("85", "Wimbledon")])],
            [], // empty page stops pagination early
        ])

        await vm.load()

        XCTAssertEqual(repo.fetchedCursorCount, 2)
        XCTAssertEqual(vm.liveGroups.flatMap(\.events).map(\.id), ["a1"])
    }

    func test_load_noEvents_fails() async {
        let (vm, _) = makeVM(pages: [[]])
        await vm.load()
        guard case .failed = vm.state else { return XCTFail("expected .failed, got \(vm.state)") }
    }

    func test_selectFuturesSport_reloadsFuturesEvents() async {
        let (vm, repo) = makeVM(pages: [[
            event("nba-sample", tags: [tag("101", "NBA")]),
            event("epl-sample", tags: [tag("102", "EPL")]),
        ]])
        repo.futuresPages["101"] = [event("nba-champ", tags: [])]
        repo.futuresPages["102"] = [event("epl-winner", tags: [])]

        await vm.load()
        XCTAssertEqual(vm.selectedFuturesSportID, "101") // first futures sport auto-selected
        XCTAssertEqual(vm.futuresEvents.map(\.id), ["nba-champ"])

        await vm.selectFuturesSport("102")
        XCTAssertEqual(vm.futuresEvents.map(\.id), ["epl-winner"])
    }

    func test_selectFuturesSport_sameID_isNoOp() async {
        let (vm, repo) = makeVM(pages: [[event("nba-sample", tags: [tag("101", "NBA")])]])
        repo.futuresPages["101"] = [event("nba-champ", tags: [])]
        await vm.load()

        let fetchCountBefore = repo.futuresFetchCount
        await vm.selectFuturesSport("101")
        XCTAssertEqual(repo.futuresFetchCount, fetchCountBefore)
    }
}

@MainActor
final class SportsLeagueDetailViewModelTests: XCTestCase {
    private func event(_ id: String, title: String) -> Event {
        Event(id: id, title: title, slug: id, markets: [], volume: 0, imageURL: nil)
    }

    func test_load_success_populatesEvents() async {
        let repo = SportsFakeRepository(pages: [])
        repo.leagueEvents = [event("m1", title: "Wimbledon Final")]
        let league = SportsLeague(id: "85", title: "Wimbledon", glyph: "figure.tennis")
        let vm = SportsLeagueDetailViewModel(league: league, fetchEvents: FetchEventsUseCase(repository: repo))

        await vm.load()

        XCTAssertEqual(vm.state, .loaded)
        XCTAssertEqual(vm.events.map(\.id), ["m1"])
    }

    func test_load_empty_fails() async {
        let repo = SportsFakeRepository(pages: [])
        let league = SportsLeague(id: "85", title: "Wimbledon", glyph: "figure.tennis")
        let vm = SportsLeagueDetailViewModel(league: league, fetchEvents: FetchEventsUseCase(repository: repo))

        await vm.load()

        guard case .failed = vm.state else { return XCTFail("expected .failed, got \(vm.state)") }
    }

    func test_searchQuery_filtersVisibleEvents_caseInsensitive() async {
        let repo = SportsFakeRepository(pages: [])
        repo.leagueEvents = [event("m1", title: "Wimbledon Final"), event("m2", title: "MLB Game")]
        let league = SportsLeague(id: "85", title: "Wimbledon", glyph: "figure.tennis")
        let vm = SportsLeagueDetailViewModel(league: league, fetchEvents: FetchEventsUseCase(repository: repo))
        await vm.load()

        vm.searchQuery = "final"
        XCTAssertEqual(vm.visibleEvents.map(\.id), ["m1"])

        vm.searchQuery = ""
        XCTAssertEqual(vm.visibleEvents.map(\.id), ["m1", "m2"])
    }
}

/// A fake repository serving pre-scripted pages for the general sports feed (`pages`,
/// consumed one per call, cursor-chained), per-tag futures pages (`futuresPages`), and a
/// flat league events list (`leagueEvents`) for `SportsLeagueDetailViewModel` tests.
private final class SportsFakeRepository: MarketRepository, @unchecked Sendable {
    private var pages: [[Event]]
    var futuresPages: [String: [Event]] = [:]
    var leagueEvents: [Event] = []
    private(set) var fetchedCursorCount = 0
    private(set) var futuresFetchCount = 0

    init(pages: [[Event]]) { self.pages = pages }

    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> {
        if tagID == SportsHubViewModel.sportsTagID {
            fetchedCursorCount += 1
            let index = Int(cursor ?? "0") ?? 0
            guard index < pages.count else { return Page(items: [], nextCursor: nil) }
            let items = pages[index]
            let next = (index + 1 < pages.count && !items.isEmpty) ? String(index + 1) : nil
            return Page(items: items, nextCursor: next)
        }
        if let tagID, let futures = futuresPages[tagID] {
            futuresFetchCount += 1
            return Page(items: futures, nextCursor: nil)
        }
        return Page(items: leagueEvents, nextCursor: nil)
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

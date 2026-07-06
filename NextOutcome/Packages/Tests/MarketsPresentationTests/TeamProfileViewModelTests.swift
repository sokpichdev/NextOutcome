//
//  TeamProfileViewModelTests.swift
//  NextOutcome
//

import XCTest
import SharedDomain
@testable import MarketsPresentation
import MarketsDomain

@MainActor
final class TeamProfileViewModelTests: XCTestCase {
    private func moneyline(_ id: String, team: String, yes: Decimal, resolved: Bool = false) -> Market {
        Market(
            id: id, question: team, slug: id,
            outcomes: [Outcome(id: "\(id)-y", title: "Yes", price: yes),
                       Outcome(id: "\(id)-n", title: "No", price: 1 - yes)],
            volume: 0, liquidity: 0, endDate: nil, isResolved: resolved,
            imageURL: nil, sportsMarketType: "moneyline", groupItemTitle: team
        )
    }

    private func game(
        _ id: String, home: String, away: String, homeYes: Decimal = 0.6,
        resolved: Bool = false, kickoff: Date? = nil
    ) -> Event {
        Event(
            id: id, title: "\(home) vs. \(away)", slug: id,
            markets: [
                moneyline("\(id)-h", team: home, yes: homeYes, resolved: resolved),
                moneyline("\(id)-a", team: away, yes: 1 - homeYes, resolved: resolved),
            ],
            volume: 0, imageURL: nil, gameStartTime: kickoff
        )
    }

    private func makeVM(events: [Event], teams: [GameTeam] = [], target: TeamProfileTarget? = nil) -> (TeamProfileViewModel, TeamProfileFakeRepository) {
        let repo = TeamProfileFakeRepository(events: events, teams: teams)
        let vm = TeamProfileViewModel(
            target: target ?? TeamProfileTarget(name: "Max Holloway", logoURL: nil, colorHex: nil, league: "ufc"),
            fetchAllEvents: FetchAllEventsUseCase(repository: repo),
            fetchTeams: FetchTeamsUseCase(repository: repo)
        )
        return (vm, repo)
    }

    func test_load_findsUpcomingMatch_soonestFirst() async {
        let (vm, _) = makeVM(events: [
            game("g1", home: "Max Holloway", away: "Conor McGregor", kickoff: Date(timeIntervalSince1970: 2_000)),
            game("g2", home: "Max Holloway", away: "Someone Else", kickoff: Date(timeIntervalSince1970: 1_000)),
        ])
        await vm.load()
        XCTAssertEqual(vm.upcomingMatch?.event.id, "g2") // earlier kickoff wins
        XCTAssertEqual(vm.upcomingMatch?.opponentName, "Someone Else")
    }

    func test_load_findsMatchHistory_mostRecentFirst_withWinLoss() async {
        let (vm, _) = makeVM(events: [
            game("g1", home: "Max Holloway", away: "Fighter A", homeYes: 1.0, resolved: true, kickoff: Date(timeIntervalSince1970: 1_000)),
            game("g2", home: "Fighter B", away: "Max Holloway", homeYes: 1.0, resolved: true, kickoff: Date(timeIntervalSince1970: 2_000)),
        ])
        await vm.load()
        XCTAssertEqual(vm.matchHistory.map(\.event.id), ["g2", "g1"]) // newest first
        XCTAssertEqual(vm.matchHistory[0].won, false) // Fighter B (home) won g2, not Holloway
        XCTAssertEqual(vm.matchHistory[1].won, true)  // Holloway (home) won g1
    }

    func test_load_ignoresEventsWithoutThisTeam() async {
        let (vm, _) = makeVM(events: [game("g1", home: "Someone", away: "Someone Else")])
        await vm.load()
        XCTAssertNil(vm.upcomingMatch)
        XCTAssertTrue(vm.matchHistory.isEmpty)
    }

    func test_load_matchesTeamNameCaseInsensitively() async {
        let (vm, _) = makeVM(events: [game("g1", home: "max holloway", away: "Conor McGregor", kickoff: .now)])
        await vm.load()
        XCTAssertEqual(vm.upcomingMatch?.event.id, "g1")
    }

    func test_load_fetchesRecord_whenLeagueKnown() async {
        let target = TeamProfileTarget(name: "Max Holloway", logoURL: nil, colorHex: nil, league: "ufc")
        let (vm, _) = makeVM(
            events: [],
            teams: [GameTeam(name: "Max Holloway", abbreviation: "MAX", logoURL: nil, colorHex: nil, ordering: "", record: "27-9-0")],
            target: target
        )
        await vm.load()
        XCTAssertEqual(vm.record, "27-9-0")
    }

    func test_load_skipsRecordLookup_whenLeagueIsNil() async {
        let target = TeamProfileTarget(name: "Roger Federer", logoURL: nil, colorHex: nil, league: nil)
        let (vm, repo) = makeVM(events: [], target: target)
        await vm.load()
        XCTAssertNil(vm.record)
        XCTAssertEqual(repo.fetchTeamsCallCount, 0)
    }

    func test_state_transitionsToLoaded() async {
        let (vm, _) = makeVM(events: [])
        XCTAssertEqual(vm.state, .idle)
        await vm.load()
        XCTAssertEqual(vm.state, .loaded)
    }
}

/// A fake repository serving a flat event list (`fetchAllEvents`) and a flat team
/// directory (`fetchTeams`), for `TeamProfileViewModel` tests.
private final class TeamProfileFakeRepository: MarketRepository, @unchecked Sendable {
    private let events: [Event]
    private let teams: [GameTeam]
    private(set) var fetchTeamsCallCount = 0

    init(events: [Event], teams: [GameTeam]) {
        self.events = events
        self.teams = teams
    }

    func fetchAllEvents(tagID: String, status: EventStatus) async throws -> [Event] { events }
    func fetchTeams(league: String) async throws -> [GameTeam] {
        fetchTeamsCallCount += 1
        return teams
    }
    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> {
        Page(items: [], nextCursor: nil)
    }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchCompletedEvents(seriesID: String, limit: Int) async throws -> [Event] { [] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
    func movers(tagID: String?) async throws -> [Mover] { [] }
    func fetchEvent(slug: String) async throws -> Event { fatalError("unused") }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func searchEvents(query: String) async throws -> [Event] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
    func commenterPositions(proxyWallet: String, eventID: String) async throws -> [CommentHolding] { [] }
}

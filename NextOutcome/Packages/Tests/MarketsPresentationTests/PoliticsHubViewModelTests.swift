import XCTest
import MarketsDomain
import SharedDomain
@testable import MarketsPresentation

final class PoliticsHubViewModelTests: XCTestCase {
    private func event(_ id: String, title: String, slug: String) -> Event {
        Event(id: id, title: title, slug: slug, markets: [], volume: 0, imageURL: nil)
    }

    @MainActor
    private func makeVM(midterms: [Event] = [], referendums: [Event] = [], throwError: Bool = false) -> PoliticsHubViewModel {
        let repo = FakePoliticsRepository(midterms: midterms, referendums: referendums, shouldThrow: throwError)
        return PoliticsHubViewModel(fetchAllEvents: FetchAllEventsUseCase(repository: repo))
    }

    @MainActor
    func test_loadIfNeeded_splitsOutControlAndBalanceOfPowerEvents() async {
        let vm = makeVM(midterms: [
            event("1", title: "Which party will win the Senate in 2026?", slug: "which-party-will-win-the-senate-in-2026"),
            event("2", title: "Which party will win the House in 2026?", slug: "which-party-will-win-the-house-in-2026"),
            event("3", title: "Balance of Power: 2026 Midterms", slug: "balance-of-power-2026-midterms"),
            event("4", title: "California Senate Election Winner", slug: "california-senate"),
        ])

        await vm.loadIfNeeded()

        XCTAssertEqual(vm.senateControlEvent?.id, "1")
        XCTAssertEqual(vm.houseControlEvent?.id, "2")
        XCTAssertEqual(vm.balanceOfPowerEvent?.id, "3")
        XCTAssertEqual(vm.races.map(\.id), ["4"])
    }

    @MainActor
    func test_loadIfNeeded_dropsAggregateThematicMarkets_notJustControlSlugs() async {
        let vm = makeVM(midterms: [
            event("1", title: "How many Republican Governors after the 2026 midterm elections?", slug: "other-1"),
            event("2", title: "California Governor Election Winner", slug: "ca-gov"),
        ])

        await vm.loadIfNeeded()

        XCTAssertEqual(vm.races.map(\.id), ["2"])
    }

    @MainActor
    func test_loadIfNeeded_loadsReferendumsSeparately() async {
        let vm = makeVM(referendums: [event("r1", title: "Will Ohio's abortion referendum pass?", slug: "oh-abortion")])

        await vm.loadIfNeeded()

        XCTAssertEqual(vm.referendums.map(\.id), ["r1"])
    }

    @MainActor
    func test_loadIfNeeded_isIdempotent() async {
        let repo = FakePoliticsRepository(midterms: [], referendums: [])
        let vm = PoliticsHubViewModel(fetchAllEvents: FetchAllEventsUseCase(repository: repo))

        await vm.loadIfNeeded()
        await vm.loadIfNeeded()

        XCTAssertEqual(repo.callCount, 2)   // one call each for midterms + referendums, not four
    }

    @MainActor
    func test_load_failure_yieldsFailedState() async {
        let vm = makeVM(throwError: true)

        await vm.loadIfNeeded()

        guard case .failed = vm.state else { return XCTFail("expected .failed, got \(vm.state)") }
    }

    @MainActor
    func test_filteredRaces_scopesToSelectedChamber() async {
        let vm = makeVM(midterms: [
            event("1", title: "California Senate Election Winner", slug: "ca-senate"),
            event("2", title: "California Governor Election Winner", slug: "ca-gov"),
            event("3", title: "CA-22 House Election Winner", slug: "ca-22-house"),
        ])
        await vm.loadIfNeeded()

        vm.selectedChamber = .senate
        XCTAssertEqual(vm.filteredRaces.map(\.id), ["1"])

        vm.selectedChamber = .governor
        XCTAssertEqual(vm.filteredRaces.map(\.id), ["2"])

        vm.selectedChamber = .house
        XCTAssertEqual(vm.filteredRaces.map(\.id), ["3"])
    }

    @MainActor
    func test_filteredRaces_appliesSearchQuery_caseInsensitively() async {
        let vm = makeVM(midterms: [
            event("1", title: "California Senate Election Winner", slug: "ca-senate"),
            event("2", title: "Texas Senate Election Winner", slug: "tx-senate"),
        ])
        await vm.loadIfNeeded()
        vm.selectedChamber = .senate

        vm.searchQuery = "california"
        XCTAssertEqual(vm.filteredRaces.map(\.id), ["1"])

        vm.searchQuery = ""
        XCTAssertEqual(vm.filteredRaces.count, 2)
    }

    @MainActor
    func test_raceCount_countsPerChamber() async {
        let vm = makeVM(midterms: [
            event("1", title: "California Senate Election Winner", slug: "ca-senate"),
            event("2", title: "Texas Senate Election Winner", slug: "tx-senate"),
            event("3", title: "California Governor Election Winner", slug: "ca-gov"),
        ])
        await vm.loadIfNeeded()

        XCTAssertEqual(vm.raceCount(for: .senate), 2)
        XCTAssertEqual(vm.raceCount(for: .governor), 1)
        XCTAssertEqual(vm.raceCount(for: .house), 0)
    }
}

/// A fake repository that returns canned events per tag and records call count.
private final class FakePoliticsRepository: MarketRepository, @unchecked Sendable {
    private let midterms: [Event]
    private let referendums: [Event]
    private let shouldThrow: Bool
    private(set) var callCount = 0

    init(midterms: [Event], referendums: [Event], shouldThrow: Bool = false) {
        self.midterms = midterms
        self.referendums = referendums
        self.shouldThrow = shouldThrow
    }

    func fetchAllEvents(tagID: String, status: EventStatus) async throws -> [Event] {
        callCount += 1
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return tagID == PoliticsHubViewModel.midtermsTagID ? midterms : referendums
    }

    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> { Page(items: [], nextCursor: nil) }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
    func fetchEvent(slug: String) async throws -> Event { throw URLError(.unknown) }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
}

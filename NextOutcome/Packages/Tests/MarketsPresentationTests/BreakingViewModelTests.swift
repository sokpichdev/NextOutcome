import XCTest
import SharedDomain
import MarketsDomain
@testable import MarketsPresentation

final class BreakingCategoryTests: XCTestCase {
    func test_tagID_mapsEachPillToItsGammaTag() {
        XCTAssertNil(BreakingCategory.all.tagID)
        XCTAssertEqual(BreakingCategory.politics.tagID, "2")
        XCTAssertEqual(BreakingCategory.world.tagID, "101970")
        XCTAssertEqual(BreakingCategory.sports.tagID, "1")
        XCTAssertEqual(BreakingCategory.crypto.tagID, "21")
        XCTAssertEqual(BreakingCategory.finance.tagID, "107")
        XCTAssertEqual(BreakingCategory.tech.tagID, "1401")
        XCTAssertEqual(BreakingCategory.culture.tagID, "596")
    }

    func test_allCases_startWithAll() {
        XCTAssertEqual(BreakingCategory.allCases.first, .all)
    }
}

final class BreakingViewModelTests: XCTestCase {
    private func mover(_ id: String) -> Mover {
        Mover(id: id, question: id, eventSlug: "e-\(id)", eventTitle: id, imageURL: nil,
              probability: 0.3, dayChange: -0.4, volume24h: 1000)
    }

    @MainActor
    func test_loadIfNeeded_loadsMoversForAll() async {
        let repo = FakeMoversRepository(byTag: [nil: [mover("a"), mover("b")]])
        let vm = BreakingViewModel(fetchMovers: FetchMoversUseCase(repository: repo))

        await vm.loadIfNeeded()

        guard case .loaded(let movers) = vm.state else { return XCTFail("expected .loaded, got \(vm.state)") }
        XCTAssertEqual(movers.map(\.id), ["a", "b"])
        XCTAssertEqual(repo.callCount, 1)
    }

    @MainActor
    func test_loadIfNeeded_isIdempotent_afterLoaded() async {
        let repo = FakeMoversRepository(byTag: [nil: [mover("a")]])
        let vm = BreakingViewModel(fetchMovers: FetchMoversUseCase(repository: repo))

        await vm.loadIfNeeded()
        await vm.loadIfNeeded()   // second call is a no-op once loaded

        XCTAssertEqual(repo.callCount, 1)
    }

    @MainActor
    func test_select_scopesToPillTag_andReloads() async {
        let repo = FakeMoversRepository(byTag: [nil: [mover("a")], "1": [mover("s1"), mover("s2")]])
        let vm = BreakingViewModel(fetchMovers: FetchMoversUseCase(repository: repo))
        await vm.loadIfNeeded()

        await vm.select(.sports)

        XCTAssertEqual(vm.category, .sports)
        XCTAssertEqual(repo.lastTag, "1")
        guard case .loaded(let movers) = vm.state else { return XCTFail("expected .loaded") }
        XCTAssertEqual(movers.map(\.id), ["s1", "s2"])
    }

    @MainActor
    func test_select_sameCategory_isNoOp() async {
        let repo = FakeMoversRepository(byTag: [nil: [mover("a")]])
        let vm = BreakingViewModel(fetchMovers: FetchMoversUseCase(repository: repo))
        await vm.loadIfNeeded()

        await vm.select(.all)

        XCTAssertEqual(repo.callCount, 1)
    }

    @MainActor
    func test_load_emptyResult_yieldsEmptyState() async {
        let repo = FakeMoversRepository(byTag: [nil: []])
        let vm = BreakingViewModel(fetchMovers: FetchMoversUseCase(repository: repo))

        await vm.loadIfNeeded()

        guard case .empty = vm.state else { return XCTFail("expected .empty, got \(vm.state)") }
    }

    @MainActor
    func test_load_failure_yieldsFailedState() async {
        let repo = FakeMoversRepository(byTag: [:], shouldThrow: true)
        let vm = BreakingViewModel(fetchMovers: FetchMoversUseCase(repository: repo))

        await vm.loadIfNeeded()

        guard case .failed = vm.state else { return XCTFail("expected .failed, got \(vm.state)") }
    }
}

/// A fake repository that returns canned movers per tag and records how it was called.
private final class FakeMoversRepository: MarketRepository, @unchecked Sendable {
    private let byTag: [String?: [Mover]]
    private let shouldThrow: Bool
    private(set) var callCount = 0
    private(set) var lastTag: String??

    init(byTag: [String?: [Mover]], shouldThrow: Bool = false) {
        self.byTag = byTag
        self.shouldThrow = shouldThrow
    }

    func movers(tagID: String?) async throws -> [Mover] {
        callCount += 1
        lastTag = tagID
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return byTag[tagID] ?? []
    }

    // Unused conformance — the protocol's defaults cover the optional methods.
    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> { Page(items: [], nextCursor: nil) }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
    func fetchEvent(slug: String) async throws -> Event { fatalError("unused") }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
}

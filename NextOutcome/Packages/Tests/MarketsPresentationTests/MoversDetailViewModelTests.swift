import XCTest
import MarketsDomain
import SharedDomain
@testable import MarketsPresentation

final class MoversDetailViewModelTests: XCTestCase {
    private func market(
        id: String, groupItemTitle: String? = nil, endDate: Date?, isResolved: Bool = false, yes: Double = 0.5
    ) -> Market {
        Market(id: id, question: id, slug: id,
               outcomes: [Outcome(id: "\(id)-yes", title: "Yes", price: Decimal(yes)),
                          Outcome(id: "\(id)-no", title: "No", price: Decimal(1 - yes))],
               volume: 0, liquidity: 0, endDate: endDate, isResolved: isResolved, imageURL: nil,
               groupItemTitle: groupItemTitle)
    }

    private func mover(id: String = "m1", eventSlug: String = "e1") -> Mover {
        Mover(id: id, question: "Q", eventSlug: eventSlug, eventTitle: "Event", imageURL: nil,
              probability: 0.5, dayChange: 0.1, volume24h: 100)
    }

    /// A minimal social-strip builder for tests — never actually fetches (no use cases are
    /// exercised in these tests), just proves `load()` wires a non-nil social strip.
    private func makeSocialStrip() -> @MainActor (String, String?, [Market]) -> SocialStripViewModel {
        let repo = EmptyMarketRepository()
        return { eventID, conditionId, markets in
            SocialStripViewModel(
                eventID: eventID, conditionId: conditionId, markets: markets,
                fetchComments: FetchCommentsUseCase(repository: repo), fetchHolders: FetchHoldersUseCase(repository: repo),
                fetchActivity: FetchActivityTradesUseCase(repository: repo), fetchCommenterPositions: FetchCommenterPositionsUseCase(repository: repo)
            )
        }
    }

    @MainActor
    private func makeVM(mover: Mover, fetchEvent: @escaping @Sendable (String) async throws -> Event) -> MoversDetailViewModel {
        MoversDetailViewModel(mover: mover, fetchEvent: fetchEvent, makeSocialStrip: makeSocialStrip())
    }

    /// Distinct end dates (a "released by \<date\>" cumulative ladder) sort by that real date.
    @MainActor
    func test_listingMarkets_distinctEndDates_sortsByRealEndDate() async {
        let event = Event.fixture(markets: [
            market(id: "july-8", endDate: Date(timeIntervalSince1970: 3)),
            market(id: "july-6", endDate: Date(timeIntervalSince1970: 1)),
            market(id: "july-7", endDate: Date(timeIntervalSince1970: 2)),
        ])
        let vm = makeVM(mover: mover(), fetchEvent: { _ in event })

        await vm.load()

        XCTAssertEqual(vm.listingMarkets.map(\.id), ["july-6", "july-7", "july-8"])
    }

    /// A shared end date (a "released on \<date\>" pick-one) can't be sorted by `endDate`
    /// directly (every market has the same one) — the specific day lives in the label text, so
    /// sorting must parse it out of `groupItemTitle` instead.
    @MainActor
    func test_listingMarkets_sharedEndDate_sortsByParsedLabelDate() async {
        let sameSettlement = Date(timeIntervalSince1970: 999)
        let event = Event.fixture(markets: [
            market(id: "july-9", groupItemTitle: "July 9", endDate: sameSettlement),
            market(id: "june-25", groupItemTitle: "June 25", endDate: sameSettlement),
            market(id: "july-7", groupItemTitle: "July 7", endDate: sameSettlement),
        ])
        let vm = makeVM(mover: mover(), fetchEvent: { _ in event })

        await vm.load()

        XCTAssertEqual(vm.listingMarkets.map(\.id), ["june-25", "july-7", "july-9"])
    }

    /// A label with no parseable date (e.g. "Not released before August") sorts after every
    /// dated candidate, ranked among itself by highest chance first.
    @MainActor
    func test_listingMarkets_undatedLabel_sortsLast_byChanceDescending() async {
        let sameSettlement = Date(timeIntervalSince1970: 999)
        let event = Event.fixture(markets: [
            market(id: "catch-all-low", groupItemTitle: "Not released before August", endDate: sameSettlement, yes: 0.02),
            market(id: "july-9", groupItemTitle: "July 9", endDate: sameSettlement, yes: 0.5),
            market(id: "catch-all-high", groupItemTitle: "Never", endDate: sameSettlement, yes: 0.3),
        ])
        let vm = makeVM(mover: mover(), fetchEvent: { _ in event })

        await vm.load()

        XCTAssertEqual(vm.listingMarkets.map(\.id), ["july-9", "catch-all-high", "catch-all-low"])
    }

    /// Resolved candidates (past deadlines/days that already came and went) are excluded.
    @MainActor
    func test_listingMarkets_dropsResolvedCandidates() async {
        let event = Event.fixture(markets: [
            market(id: "past", endDate: Date(timeIntervalSince1970: 1), isResolved: true),
            market(id: "upcoming", endDate: Date(timeIntervalSince1970: 2), isResolved: false),
            market(id: "later", endDate: Date(timeIntervalSince1970: 3), isResolved: false),
        ])
        let vm = makeVM(mover: mover(), fetchEvent: { _ in event })

        await vm.load()

        XCTAssertEqual(vm.listingMarkets.map(\.id), ["upcoming", "later"])
    }

    /// A fully-resolved (historical) event has no open candidates to prefer — falls back to
    /// listing the resolved markets themselves rather than showing an empty listing.
    @MainActor
    func test_listingMarkets_fullyResolvedEvent_fallsBackToResolvedMarkets() async {
        let event = Event.fixture(markets: [
            market(id: "winner", endDate: Date(timeIntervalSince1970: 1), isResolved: true),
            market(id: "loser", endDate: Date(timeIntervalSince1970: 2), isResolved: true),
        ])
        let vm = makeVM(mover: mover(), fetchEvent: { _ in event })

        await vm.load()

        XCTAssertEqual(vm.listingMarkets.count, 2)
    }

    @MainActor
    func test_listingMarkets_empty_beforeEventLoads() {
        let vm = makeVM(mover: mover(), fetchEvent: { _ in .fixture() })

        XCTAssertTrue(vm.listingMarkets.isEmpty)
    }

    /// Regression test: the social strip must be built synchronously as part of `load()` (not
    /// via a separate environment-dependent step), so the Discuss sheet always has real
    /// content the instant it's presented — no risk of a blank sheet from timing/propagation.
    @MainActor
    func test_load_buildsSocialStrip() async {
        let event = Event.fixture(markets: [
            market(id: "a", endDate: Date(timeIntervalSince1970: 1)),
            market(id: "b", endDate: Date(timeIntervalSince1970: 2)),
        ])
        let vm = makeVM(mover: mover(), fetchEvent: { _ in event })

        await vm.load()

        XCTAssertNotNil(vm.socialStrip)
    }
}

/// A minimal repository stub for building a `SocialStripViewModel` in tests — every method
/// returns an empty/throwing result since these tests only check that a strip is *built*,
/// never that it fetches real data.
private struct EmptyMarketRepository: MarketRepository {
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

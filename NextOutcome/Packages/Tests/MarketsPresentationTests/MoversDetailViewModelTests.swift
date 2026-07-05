import XCTest
import MarketsDomain
import SharedDomain
import OrderbookDomain
import OrderbookPresentation
@testable import MarketsPresentation

final class MoversDetailViewModelTests: XCTestCase {
    private func market(id: String, endDate: Date?, isResolved: Bool = false) -> Market {
        Market(id: id, question: id, slug: id,
               outcomes: [Outcome(id: "\(id)-yes", title: "Yes", price: 0.5),
                          Outcome(id: "\(id)-no", title: "No", price: 0.5)],
               volume: 0, liquidity: 0, endDate: endDate, isResolved: isResolved, imageURL: nil)
    }

    private func mover(id: String = "m1", eventSlug: String = "e1") -> Mover {
        Mover(id: id, question: "Q", eventSlug: eventSlug, eventTitle: "Event", imageURL: nil,
              probability: 0.5, dayChange: 0.1, volume24h: 100)
    }

    private func provider() -> PriceHistoryProvider {
        PriceHistoryProvider { _, _ in [PriceHistoryPoint.fixture()] }
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
        MoversDetailViewModel(mover: mover, fetchEvent: fetchEvent, provider: provider(), makeSocialStrip: makeSocialStrip())
    }

    @MainActor
    func test_load_chartEvent_buildsChart_andEmptyDateLadder() async {
        let sameDate = Date()
        let event = Event.fixture(markets: [
            market(id: "spain", endDate: sameDate),
            market(id: "france", endDate: sameDate),
        ])
        let vm = makeVM(mover: mover(), fetchEvent: { _ in event })

        await vm.load()

        XCTAssertEqual(vm.layout, .chart)
        XCTAssertNotNil(vm.chart)
        XCTAssertTrue(vm.dateLadderMarkets.isEmpty)
    }

    @MainActor
    func test_load_dateLadderEvent_skipsChart_andSortsRowsByDeadline() async {
        let event = Event.fixture(markets: [
            market(id: "july-8", endDate: Date(timeIntervalSince1970: 3)),
            market(id: "july-6", endDate: Date(timeIntervalSince1970: 1)),
            market(id: "july-7", endDate: Date(timeIntervalSince1970: 2)),
        ])
        let vm = makeVM(mover: mover(), fetchEvent: { _ in event })

        await vm.load()

        XCTAssertEqual(vm.layout, .dateLadder)
        XCTAssertNil(vm.chart)   // chart-building is skipped entirely for date-ladder events
        XCTAssertEqual(vm.dateLadderMarkets.map(\.id), ["july-6", "july-7", "july-8"])
    }

    @MainActor
    func test_dateLadderMarkets_dropsResolvedDeadlines() async {
        let event = Event.fixture(markets: [
            market(id: "past", endDate: Date(timeIntervalSince1970: 1), isResolved: true),
            market(id: "upcoming", endDate: Date(timeIntervalSince1970: 2), isResolved: false),
            market(id: "later", endDate: Date(timeIntervalSince1970: 3), isResolved: false),
        ])
        let vm = makeVM(mover: mover(), fetchEvent: { _ in event })

        await vm.load()

        XCTAssertEqual(vm.dateLadderMarkets.map(\.id), ["upcoming", "later"])
    }

    @MainActor
    func test_layout_defaultsToChart_beforeEventLoads() {
        let vm = makeVM(mover: mover(), fetchEvent: { _ in .fixture() })

        XCTAssertEqual(vm.layout, .chart)
        XCTAssertTrue(vm.dateLadderMarkets.isEmpty)
    }

    /// Regression test: the social strip must be built synchronously as part of `load()` (not
    /// via a separate environment-dependent step), so the Discuss sheet always has real
    /// content the instant it's presented — no risk of a blank sheet from timing/propagation.
    @MainActor
    func test_load_buildsSocialStrip_forBothLayouts() async {
        let chartEvent = Event.fixture(markets: [
            market(id: "a", endDate: Date()), market(id: "b", endDate: Date()),
        ])
        let chartVM = makeVM(mover: mover(), fetchEvent: { _ in chartEvent })
        await chartVM.load()
        XCTAssertNotNil(chartVM.socialStrip)

        let ladderEvent = Event.fixture(markets: [
            market(id: "c", endDate: Date(timeIntervalSince1970: 1)),
            market(id: "d", endDate: Date(timeIntervalSince1970: 2)),
        ])
        let ladderVM = makeVM(mover: mover(), fetchEvent: { _ in ladderEvent })
        await ladderVM.load()
        XCTAssertNotNil(ladderVM.socialStrip)
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

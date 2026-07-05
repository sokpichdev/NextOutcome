import XCTest
import MarketsDomain
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

    @MainActor
    func test_load_chartEvent_buildsChart_andEmptyDateLadder() async {
        let sameDate = Date()
        let event = Event.fixture(markets: [
            market(id: "spain", endDate: sameDate),
            market(id: "france", endDate: sameDate),
        ])
        let vm = MoversDetailViewModel(mover: mover(), fetchEvent: { _ in event }, provider: provider())

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
        let vm = MoversDetailViewModel(mover: mover(), fetchEvent: { _ in event }, provider: provider())

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
        let vm = MoversDetailViewModel(mover: mover(), fetchEvent: { _ in event }, provider: provider())

        await vm.load()

        XCTAssertEqual(vm.dateLadderMarkets.map(\.id), ["upcoming", "later"])
    }

    @MainActor
    func test_layout_defaultsToChart_beforeEventLoads() {
        let vm = MoversDetailViewModel(mover: mover(), fetchEvent: { _ in .fixture() }, provider: provider())

        XCTAssertEqual(vm.layout, .chart)
        XCTAssertTrue(vm.dateLadderMarkets.isEmpty)
    }
}

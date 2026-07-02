import XCTest
@testable import MarketsPresentation
import MarketsDomain
import OrderbookDomain
import OrderbookPresentation

final class EventChartViewModelTests: XCTestCase {
    private func market(_ name: String, yes: Double) -> Market {
        Market(id: name, question: name, slug: name,
               outcomes: [Outcome(id: "\(name)-yes", title: "Yes", price: Decimal(yes)),
                          Outcome(id: "\(name)-no", title: "No", price: Decimal(1 - yes))],
               volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil)
    }

    @MainActor
    func test_load_buildsOneSeriesPerMarket_withLabelsAndColors() async {
        let event = Event(id: "e", title: "World Cup Winner", slug: "wc",
                          markets: [market("France", yes: 0.33), market("Argentina", yes: 0.19)],
                          volume: 0, imageURL: nil, tags: [])
        let provider = PriceHistoryProvider { assetID, _ in
            [PriceHistoryPoint(date: Date(), price: assetID.contains("France") ? 0.33 : 0.19)]
        }
        let vm = EventChartViewModel(event: event, provider: provider)
        await vm.load()
        XCTAssertEqual(vm.series.map(\.label), ["France", "Argentina"])
        XCTAssertEqual(vm.series.count, 2)
        XCTAssertNotEqual(vm.series[0].color, vm.series[1].color)
        XCTAssertEqual(vm.series[0].points.last?.price ?? 0, 0.33, accuracy: 0.001)
    }
}

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

    /// Regression test: rapidly changing `timeframe` spawns overlapping unstructured
    /// `load()` Tasks via `didSet`. An older, slower fetch (e.g. `.max`, which returns
    /// long history and takes longer to resolve) must not be allowed to overwrite
    /// `series` after a newer, faster fetch (e.g. `.h1`) already completed.
    @MainActor
    func test_rapidTimeframeChange_newestLoadWins_evenIfOlderLoadResolvesLater() async {
        let event = Event(id: "e", title: "World Cup Winner", slug: "wc",
                          markets: [market("France", yes: 0.33)],
                          volume: 0, imageURL: nil, tags: [])
        let provider = PriceHistoryProvider { _, interval in
            if interval == .max {
                try? await Task.sleep(nanoseconds: 300_000_000) // slow, stale-by-the-time-it-resolves fetch
                return [PriceHistoryPoint(date: Date(), price: 0.11)]
            } else {
                try? await Task.sleep(nanoseconds: 20_000_000) // fast, newest fetch
                return [PriceHistoryPoint(date: Date(), price: 0.99)]
            }
        }
        let vm = EventChartViewModel(event: event, provider: provider)

        // Trigger the slow (.max) load first and let its unstructured Task actually
        // start and capture its interval before switching the timeframe again.
        vm.timeframe = .max
        await Task.yield()
        // Switch away before the slow load resolves; this spawns a second, faster
        // unstructured load that will finish first.
        vm.timeframe = .h1

        // Wait for both overlapping loads to resolve.
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(vm.series.first?.points.last?.price ?? 0, 0.99, accuracy: 0.001,
                       "series must reflect the newest selected timeframe (.h1), not a stale slower load that resolved later")
    }
}

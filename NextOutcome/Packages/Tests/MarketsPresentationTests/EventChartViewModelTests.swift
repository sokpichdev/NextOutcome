import XCTest
@testable import MarketsPresentation
import MarketsDomain
import OrderbookDomain
import OrderbookPresentation
import SharedDomain

/// Deterministic gate used to control exactly when a provider call resolves, so
/// concurrency/race tests don't depend on timing (sleeps) — see
/// `test_rapidTimeframeChange_newestLoadWins_evenIfOlderLoadResolvesLater`.
private actor Gate {
    private var isReleased = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isReleased { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        isReleased = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

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

        guard case .loaded(let series) = vm.state else { return XCTFail("expected .loaded, got \(vm.state)") }
        XCTAssertEqual(series.map(\.label), ["France", "Argentina"])
        XCTAssertEqual(series.count, 2)
        XCTAssertNotEqual(series[0].color, series[1].color)
        XCTAssertEqual(series[0].points.last?.price ?? 0, 0.33, accuracy: 0.001)
    }

    /// Regression test: rapidly changing `timeframe` spawns overlapping unstructured
    /// `load()` Tasks via `didSet`. An older, slower fetch (e.g. `.max`) must not be
    /// allowed to overwrite `state` after a newer, faster fetch (e.g. `.h1`) already
    /// completed. Deterministic: the slow fetch is held open by a `Gate` and only
    /// released after the fast fetch has already won, so there is no reliance on
    /// sleep timing to reproduce the race.
    @MainActor
    func test_rapidTimeframeChange_newestLoadWins_evenIfOlderLoadResolvesLater() async {
        let event = Event(id: "e", title: "World Cup Winner", slug: "wc",
                          markets: [market("France", yes: 0.33)],
                          volume: 0, imageURL: nil, tags: [])
        let gate = Gate()
        let provider = PriceHistoryProvider { _, interval in
            if interval == .max {
                await gate.wait() // slow, held-open fetch — resolves only when the test releases it
                return [PriceHistoryPoint(date: Date(), price: 0.11)]
            } else {
                return [PriceHistoryPoint(date: Date(), price: 0.99)] // fast, newest fetch
            }
        }
        let vm = EventChartViewModel(event: event, provider: provider)

        // Trigger the slow (.max) load first and let its unstructured Task actually
        // start (and block on the gate) before switching the timeframe again.
        vm.timeframe = .max
        await Task.yield()
        // Switch away before the slow load resolves; this spawns a second, faster
        // unstructured load that will finish first.
        vm.timeframe = .h1

        // Wait for the fast (.h1) load to win.
        for _ in 0..<1000 {
            if case .loaded(let series) = vm.state, series.first?.points.last?.price == 0.99 { break }
            await Task.yield()
        }

        // Now release the stale slow (.max) load. Its result must be discarded by the
        // `loadGeneration` guard rather than overwriting the already-current state.
        await gate.release()
        for _ in 0..<10 { await Task.yield() }

        guard case .loaded(let series) = vm.state else { return XCTFail("expected .loaded, got \(vm.state)") }
        XCTAssertEqual(series.first?.points.last?.price ?? 0, 0.99, accuracy: 0.001,
                       "state must reflect the newest selected timeframe (.h1), not a stale slower load that resolved later")
    }
}

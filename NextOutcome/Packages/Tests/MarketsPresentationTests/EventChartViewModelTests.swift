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
    private func market(_ name: String, yes: Double, isResolved: Bool = false) -> Market {
        Market(id: name, question: name, slug: name,
               outcomes: [Outcome(id: "\(name)-yes", title: "Yes", price: Decimal(yes)),
                          Outcome(id: "\(name)-no", title: "No", price: Decimal(1 - yes))],
               volume: 0, liquidity: 0, endDate: nil, isResolved: isResolved, imageURL: nil)
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

    /// Regression test: a multi-candidate event (e.g. "GPT-5.6 released on…?" — one market
    /// per specific day) can carry dozens of markets in arbitrary array order. The top 4
    /// charted must be the 4 highest-Yes-probability markets, not whichever 4 happen to sit
    /// first in the array (which was often stale near-zero noise).
    @MainActor
    func test_load_picksTop4ByYesProbability_regardlessOfArrayOrder() async {
        let event = Event(
            id: "e", title: "GPT-5.6 released on…?", slug: "gpt",
            markets: [
                market("June25", yes: 0.001),   // low-probability noise, listed first
                market("June26", yes: 0.001),
                market("July9", yes: 0.52),      // the real leaders, listed later
                market("July7", yes: 0.1575),
                market("July8", yes: 0.0935),
                market("July16", yes: 0.0745),
            ],
            volume: 0, imageURL: nil, tags: []
        )
        let provider = PriceHistoryProvider { assetID, _ in [PriceHistoryPoint(date: Date(), price: 0.5)] }
        let vm = EventChartViewModel(event: event, provider: provider)
        await vm.load()

        guard case .loaded(let series) = vm.state else { return XCTFail("expected .loaded, got \(vm.state)") }
        XCTAssertEqual(series.map(\.label), ["July9", "July7", "July8", "July16"])
    }

    /// Already-resolved sibling markets (e.g. past days that came and went) are excluded from
    /// the top 4 in favor of still-open markets, even when a resolved market's stale price
    /// would otherwise outrank them.
    @MainActor
    func test_load_prefersOpenMarkets_overResolvedOnes() async {
        let event = Event(
            id: "e", title: "GPT-5.6 released on…?", slug: "gpt",
            markets: [
                market("StaleResolved", yes: 0.99, isResolved: true),
                market("July9", yes: 0.52),
                market("July7", yes: 0.1575),
            ],
            volume: 0, imageURL: nil, tags: []
        )
        let provider = PriceHistoryProvider { assetID, _ in [PriceHistoryPoint(date: Date(), price: 0.5)] }
        let vm = EventChartViewModel(event: event, provider: provider)
        await vm.load()

        guard case .loaded(let series) = vm.state else { return XCTFail("expected .loaded, got \(vm.state)") }
        XCTAssertEqual(series.map(\.label), ["July9", "July7"])
    }

    /// A fully-resolved (historical) event has no open markets to prefer — falls back to
    /// charting the resolved markets themselves rather than showing an empty chart.
    @MainActor
    func test_load_fullyResolvedEvent_fallsBackToResolvedMarkets() async {
        let event = Event(
            id: "e", title: "Past event", slug: "past",
            markets: [
                market("Winner", yes: 1.0, isResolved: true),
                market("Loser", yes: 0.0, isResolved: true),
            ],
            volume: 0, imageURL: nil, tags: []
        )
        let provider = PriceHistoryProvider { assetID, _ in [PriceHistoryPoint(date: Date(), price: 0.5)] }
        let vm = EventChartViewModel(event: event, provider: provider)
        await vm.load()

        guard case .loaded(let series) = vm.state else { return XCTFail("expected .loaded, got \(vm.state)") }
        XCTAssertEqual(series.map(\.label), ["Winner", "Loser"])
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

import XCTest
@testable import OrderbookPresentation
import OrderbookDomain
import SharedDomain
import Foundation

/// Deterministic gate used to hold a fake repository call open until the test explicitly
/// releases it, so races (e.g. teardown vs. a late-completing load) don't depend on
/// sleep timing. Mirrors the pattern used in EventChartViewModelTests.
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

/// Minimal fake `OrderbookRepository`. `historyGate`, when set, blocks `priceHistory`
/// until released, so tests can control exactly when `load()` completes.
private final class FakeOrderbookRepository: OrderbookRepository, @unchecked Sendable {
    var points: [PriceHistoryPoint] = []
    var serverNow: Date = Date()
    var historyGate: Gate?

    func book(assetID: String) async throws -> OrderBook {
        OrderBook(assetID: assetID)
    }

    func priceHistory(assetID: String, interval: PriceHistoryInterval) async throws -> [PriceHistoryPoint] {
        if let historyGate {
            await historyGate.wait()
        }
        return points
    }

    func serverTime() async throws -> Date {
        serverNow
    }

    func recentTrades(eventID: String, limit: Int) async throws -> [RecentTrade] {
        []
    }
}

/// No-op streaming source: never yields, so `streamBook()` just idles until cancelled.
private struct FakeMarketStreaming: MarketStreaming {
    func events(assetID: String) -> AsyncStream<OrderBookEvent> {
        AsyncStream { _ in }
    }
}

final class BTCLiveViewModelTests: XCTestCase {
    @MainActor
    private func makeVM(
        repository: FakeOrderbookRepository,
        windowEnd: Date
    ) -> BTCLiveViewModel {
        BTCLiveViewModel(
            assetID: "asset-1",
            eventID: "event-1",
            windowEnd: windowEnd,
            fetchHistory: FetchPriceHistoryUseCase(repository: repository),
            fetchServerTime: FetchServerTimeUseCase(repository: repository),
            fetchRecentTrades: FetchRecentTradesUseCase(repository: repository),
            observeBook: ObserveOrderBookUseCase(repository: repository, stream: FakeMarketStreaming()),
            onQuickBet: { _ in }
        )
    }

    /// Regression test for the sliding-window bug: `priceToBeat` must be pinned to the
    /// window's fixed open time (`windowEnd - windowInterval`), not to `now`. Feeds a
    /// fixed point set and advances the simulated server clock across several ticks
    /// within the same window; the selected price must never change.
    @MainActor
    func test_priceToBeat_staysConstant_asServerTimeAdvancesWithinWindow() async {
        let windowEnd = Date(timeIntervalSince1970: 1_000_000)
        let windowOpen = windowEnd.addingTimeInterval(-300) // windowInterval = 300s

        let repository = FakeOrderbookRepository()
        repository.points = [
            PriceHistoryPoint(date: windowOpen.addingTimeInterval(-120), price: 0.10), // before window
            PriceHistoryPoint(date: windowOpen, price: 0.42),                          // window open — expected pick
            PriceHistoryPoint(date: windowOpen.addingTimeInterval(30), price: 0.55),
            PriceHistoryPoint(date: windowOpen.addingTimeInterval(90), price: 0.61),
        ]
        repository.serverNow = windowOpen.addingTimeInterval(10)

        let vm = makeVM(repository: repository, windowEnd: windowEnd)
        await vm.retry() // drives load() synchronously to completion (awaited)

        let first = vm.priceToBeat
        XCTAssertEqual(first, 0.42)

        // Simulate the server clock (and hence `now`) advancing within the same window
        // by refreshing the countdown repeatedly; `priceToBeat` must not move.
        for _ in 0..<5 {
            await Task.yield()
            XCTAssertEqual(vm.priceToBeat, 0.42, "priceToBeat must stay pinned to the window open, not drift with now")
        }
        XCTAssertEqual(vm.priceToBeat, first)
    }

    /// Regression test for the teardown leak: calling `stop()` while the initial
    /// `load()` is still in flight must prevent that load from resurrecting the
    /// countdown ticker once it resolves. We gate `priceHistory` open, start the VM,
    /// stop it before the gate is released, then release the gate and verify the VM
    /// stays torn down (no ticking resumes, `isStopped` remains true).
    @MainActor
    func test_stopBeforeLoadCompletes_preventsTickerFromStartingAfterTeardown() async {
        let windowEnd = Date().addingTimeInterval(300)
        let repository = FakeOrderbookRepository()
        repository.points = [PriceHistoryPoint(date: Date(), price: 0.5)]
        repository.serverNow = Date()
        let gate = Gate()
        repository.historyGate = gate

        let vm = makeVM(repository: repository, windowEnd: windowEnd)

        vm.start()
        // Let the unstructured load task actually start and block on the gate.
        for _ in 0..<10 { await Task.yield() }

        vm.stop()
        XCTAssertTrue(vm.isStopped)
        let countdownAtStop = vm.countdown

        // Now let the late load resolve. Per the fix, it must observe `isStopped` and
        // bail out before calling `startTicking()`.
        await gate.release()
        for _ in 0..<20 { await Task.yield() }

        // The VM must remain torn down: still stopped, and the countdown must not have
        // been mutated by a resurrected ticker (it never got the chance to start
        // ticking, so refreshCountdown never re-ran after teardown).
        XCTAssertTrue(vm.isStopped, "stop() state must not be undone by a late-completing load()")
        XCTAssertEqual(vm.countdown, countdownAtStop, "no ticker should have resumed updating the countdown after stop()")
    }
}

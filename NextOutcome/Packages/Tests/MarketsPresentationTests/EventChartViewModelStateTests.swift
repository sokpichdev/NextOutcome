import XCTest
@testable import MarketsPresentation
import MarketsDomain
import OrderbookDomain
import OrderbookPresentation
import SharedDomain

/// Thread-safe one-shot flag for `testRetryAfterFailureLoads` — avoids capturing a
/// mutable `var` in the `@Sendable` provider closure.
private actor FailOnce {
    private var shouldFail = true
    func consume() -> Bool {
        defer { shouldFail = false }
        return shouldFail
    }
}

/// Thread-safe counter to track load calls.
private actor LoadCounter {
    private var count = 0
    func increment() -> Int {
        count += 1
        return count
    }
}

/// Deterministic gate used to control exactly when a provider call resolves, so
/// concurrency/race tests don't depend on timing (sleeps).
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

final class EventChartViewModelStateTests: XCTestCase {
    @MainActor
    func testProviderErrorLandsInFailedState() async {
        let provider = PriceHistoryProvider { _, _ in throw URLError(.notConnectedToInternet) }
        let vm = EventChartViewModel(event: .fixture(), provider: provider)
        await vm.load()
        guard case .failed = vm.state else { return XCTFail("expected .failed, got \(vm.state)") }
    }

    @MainActor
    func testRetryAfterFailureLoads() async {
        let failOnce = FailOnce()
        let provider = PriceHistoryProvider { _, _ in
            if await failOnce.consume() { throw URLError(.timedOut) }
            return [.fixture()]
        }
        let vm = EventChartViewModel(event: .fixture(), provider: provider)
        await vm.load()
        await vm.retry()
        guard case .loaded = vm.state else { return XCTFail("expected .loaded, got \(vm.state)") }
    }

    @MainActor
    func testReloadKeepsPreviousChartVisible() async {
        let gate = Gate()
        let counter = LoadCounter()

        let provider = PriceHistoryProvider { _, _ in
            let callNumber = await counter.increment()
            if callNumber == 1 {
                // First load succeeds immediately
                return [.fixture()]
            } else {
                // Second load hangs at the gate
                await gate.wait()
                return [.fixture()]
            }
        }

        let vm = EventChartViewModel(event: .fixture(), provider: provider)

        // First load: complete successfully
        await vm.load()
        guard case .loaded = vm.state else { return XCTFail("first load should succeed") }

        // Start a second load that will hang at the gate
        Task { await vm.load() }

        // Yield control several times to let the task start and hit the gate
        for _ in 0..<10 { await Task.yield() }

        // State should still be .loaded, not .loading
        guard case .loaded = vm.state else {
            return XCTFail("expected .loaded during reload, got \(vm.state)")
        }
    }

    @MainActor
    func testFailureMessageIsSanitized() async {
        let provider = PriceHistoryProvider { _, _ in throw URLError(.cannotFindHost) }
        let vm = EventChartViewModel(event: .fixture(), provider: provider)
        await vm.load()

        guard case .failed(let message) = vm.state else {
            return XCTFail("expected .failed, got \(vm.state)")
        }

        let expectedMessage = "Couldn't load chart data. Check your connection and try again."
        XCTAssertEqual(message, expectedMessage)
        XCTAssertFalse(message.contains("Host"), "message should not contain 'Host'")
        XCTAssertFalse(message.contains(URLError(.cannotFindHost).localizedDescription),
                       "message should not contain URLError description")
    }
}

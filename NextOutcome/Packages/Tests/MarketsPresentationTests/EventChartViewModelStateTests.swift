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
}

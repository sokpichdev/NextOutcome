import XCTest
import TradingDomain
@testable import TradingPresentation

/// Returns a queued sequence of results, so a test can say "succeed, then fail".
private final class StubGeoblockService: GeoblockService, @unchecked Sendable {
    private var results: [Result<GeoblockStatus, Error>]

    init(_ results: [Result<GeoblockStatus, Error>]) { self.results = results }

    func status() async throws -> GeoblockStatus {
        guard !results.isEmpty else { throw StubError.exhausted }
        return try results.removeFirst().get()
    }

    enum StubError: Error { case exhausted, offline }
}

private func status(blocked: Bool = false, closeOnly: Bool = false,
                    region: String? = "US") -> GeoblockStatus {
    GeoblockStatus(blocked: blocked, closeOnly: closeOnly, region: region)
}

@MainActor
final class TradingAccessViewModelTests: XCTestCase {
    func test_startsAllowed_beforeAnyFetch() {
        let viewModel = TradingAccessViewModel(service: StubGeoblockService([]))
        XCTAssertEqual(viewModel.access, .allowed)
    }

    func test_refresh_resolvesBlocked() async {
        let viewModel = TradingAccessViewModel(service: StubGeoblockService([.success(status(blocked: true))]))
        await viewModel.refresh()
        XCTAssertEqual(viewModel.access, .blocked(region: "US"))
    }

    func test_refresh_resolvesCloseOnly() async {
        let viewModel = TradingAccessViewModel(service: StubGeoblockService([.success(status(closeOnly: true))]))
        await viewModel.refresh()
        XCTAssertEqual(viewModel.access, .closeOnly(region: "US"))
    }

    func test_refresh_resolvesAllowed() async {
        let viewModel = TradingAccessViewModel(service: StubGeoblockService([.success(status())]))
        await viewModel.refresh()
        XCTAssertEqual(viewModel.access, .allowed)
    }

    /// Fail open: a first fetch that never succeeds must not brick the sheet for
    /// everyone on a flaky connection. The proxy is the authority for real writes.
    func test_firstFetchFails_staysAllowed() async {
        let viewModel = TradingAccessViewModel(
            service: StubGeoblockService([.failure(StubGeoblockService.StubError.offline)])
        )
        await viewModel.refresh()
        XCTAssertEqual(viewModel.access, .allowed)
    }

    /// Sticky once denied: a later blip can't silently unblock someone who resolved
    /// blocked. This is the half of the failure policy that actually protects us.
    func test_blockedThenFailure_staysBlocked() async {
        let viewModel = TradingAccessViewModel(service: StubGeoblockService([
            .success(status(blocked: true)),
            .failure(StubGeoblockService.StubError.offline)
        ]))
        await viewModel.refresh()
        await viewModel.refresh()
        XCTAssertEqual(viewModel.access, .blocked(region: "US"))
    }

    /// A *successful* read still wins — someone who genuinely moved region gets unblocked.
    func test_blockedThenSuccessfulAllowed_unblocks() async {
        let viewModel = TradingAccessViewModel(service: StubGeoblockService([
            .success(status(blocked: true)),
            .success(status(region: nil))
        ]))
        await viewModel.refresh()
        await viewModel.refresh()
        XCTAssertEqual(viewModel.access, .allowed)
    }

    func test_override_forcesAllowedDespiteBlocked() async {
        let viewModel = TradingAccessViewModel(
            service: StubGeoblockService([.success(status(blocked: true))]),
            override: true
        )
        await viewModel.refresh()
        XCTAssertEqual(viewModel.access, .allowed)
    }

    /// The simulated status short-circuits the network entirely — the stub is exhausted
    /// and would throw if it were consulted.
    func test_simulatedStatus_bypassesService() async {
        let viewModel = TradingAccessViewModel(
            service: StubGeoblockService([]),
            simulated: status(closeOnly: true, region: "FR")
        )
        await viewModel.refresh()
        XCTAssertEqual(viewModel.access, .closeOnly(region: "FR"))
    }
}

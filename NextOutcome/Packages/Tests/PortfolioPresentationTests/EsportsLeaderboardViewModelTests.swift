import XCTest
@testable import PortfolioDomain
@testable import PortfolioPresentation

@MainActor
final class EsportsLeaderboardViewModelTests: XCTestCase {
    /// The whole point of this screen: esports-scoped rankings, not the global board.
    func test_load_scopesToEsports_withTheWiderPageSize() async {
        let repo = StubPortfolioRepository()
        let vm = makeViewModel(repo)

        await vm.load()

        guard let call = repo.leaderboardCalls.last else {
            return XCTFail("expected a leaderboard call")
        }
        XCTAssertEqual(call.category, "esports")
        XCTAssertEqual(call.limit, 25, "esports shows a deeper board than the global 10")
    }

    /// Defaults mirror the web experience.
    func test_defaults_areProfitOverAMonth() {
        let vm = makeViewModel(StubPortfolioRepository())

        XCTAssertEqual(vm.metric, .profit)
        XCTAssertEqual(vm.window, .month)
    }

    func test_loadIfNeeded_onlyFetchesOnce() async {
        let repo = StubPortfolioRepository()
        repo.leaderboardResult = [makeEntry()]
        let vm = makeViewModel(repo)

        await vm.loadIfNeeded()
        await vm.loadIfNeeded()
        await vm.loadIfNeeded()

        XCTAssertEqual(repo.leaderboardCalls.count, 1,
                       "the tab lazy-loads once; re-appearing must not refetch")
    }

    /// A failed first load leaves the screen retryable rather than stuck on the error.
    func test_loadIfNeeded_afterFailure_retries() async {
        let repo = StubPortfolioRepository()
        repo.leaderboardError = StubError.boom
        let vm = makeViewModel(repo)

        await vm.loadIfNeeded()
        guard case .failed = vm.state else {
            return XCTFail("expected .failed, got \(vm.state)")
        }

        repo.leaderboardError = nil
        repo.leaderboardResult = [makeEntry()]
        await vm.loadIfNeeded()

        XCTAssertEqual(repo.leaderboardCalls.count, 2, "a failed load must not count as loaded")
        guard case .loaded = vm.state else {
            return XCTFail("expected .loaded after retry, got \(vm.state)")
        }
    }

    func test_load_withNoEntries_isEmptyNotLoaded() async {
        let repo = StubPortfolioRepository()
        repo.leaderboardResult = []
        let vm = makeViewModel(repo)

        await vm.load()

        guard case .empty = vm.state else {
            return XCTFail("expected .empty, got \(vm.state)")
        }
    }

    private func makeViewModel(_ repo: StubPortfolioRepository) -> EsportsLeaderboardViewModel {
        EsportsLeaderboardViewModel(fetchLeaderboard: FetchLeaderboardUseCase(repository: repo))
    }
}

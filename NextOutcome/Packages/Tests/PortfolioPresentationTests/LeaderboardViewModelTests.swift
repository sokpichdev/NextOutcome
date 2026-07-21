import XCTest
@testable import PortfolioDomain
@testable import PortfolioPresentation

@MainActor
final class LeaderboardViewModelTests: XCTestCase {
    func test_load_withEntries_isLoaded() async {
        let repo = StubPortfolioRepository()
        repo.leaderboardResult = [makeEntry(rank: 1), makeEntry(rank: 2)]
        let vm = LeaderboardViewModel(fetchLeaderboard: FetchLeaderboardUseCase(repository: repo))

        await vm.load()

        guard case .loaded(let entries) = vm.state else {
            return XCTFail("expected .loaded, got \(vm.state)")
        }
        XCTAssertEqual(entries.count, 2)
    }

    func test_load_withNoEntries_isEmptyNotLoaded() async {
        let repo = StubPortfolioRepository()
        repo.leaderboardResult = []
        let vm = LeaderboardViewModel(fetchLeaderboard: FetchLeaderboardUseCase(repository: repo))

        await vm.load()

        guard case .empty = vm.state else {
            return XCTFail("expected .empty, got \(vm.state)")
        }
    }

    func test_load_whenFetchFails_showsFailure() async {
        let repo = StubPortfolioRepository()
        repo.leaderboardError = StubError.boom
        let vm = LeaderboardViewModel(fetchLeaderboard: FetchLeaderboardUseCase(repository: repo))

        await vm.load()

        guard case .failed = vm.state else {
            return XCTFail("expected .failed, got \(vm.state)")
        }
    }

    /// The global leaderboard must stay global — a category scope here would silently
    /// turn it into a filtered board.
    func test_load_requestsGlobalScope_withTheSelectedMetricAndWindow() async {
        let repo = StubPortfolioRepository()
        let vm = LeaderboardViewModel(fetchLeaderboard: FetchLeaderboardUseCase(repository: repo))
        vm.metric = .profit
        vm.window = .all

        await vm.load()

        guard let call = repo.leaderboardCalls.last else {
            return XCTFail("expected a leaderboard call")
        }
        XCTAssertEqual(call.metric, .profit)
        XCTAssertEqual(call.window, .all)
        XCTAssertNil(call.category, "the global board must not be category-scoped")
    }

    func test_defaults_areVolumeOverAWeek() {
        let repo = StubPortfolioRepository()
        let vm = LeaderboardViewModel(fetchLeaderboard: FetchLeaderboardUseCase(repository: repo))

        XCTAssertEqual(vm.metric, .volume)
        XCTAssertEqual(vm.window, .week)
    }
}

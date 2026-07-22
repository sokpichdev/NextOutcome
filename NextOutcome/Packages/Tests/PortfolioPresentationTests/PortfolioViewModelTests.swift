import XCTest
@testable import PortfolioDomain
@testable import PortfolioPresentation

@MainActor
final class PortfolioViewModelTests: XCTestCase {
    // MARK: - Address gating

    func test_start_withNoSavedAddress_promptsForOne() async {
        let (vm, repo) = makeViewModel()
        await vm.start()
        assertState(vm.state, isNeedsAddress: true)
        // Nothing should be fetched before a wallet is known.
        XCTAssertEqual(repo.positionsCallCount, 0)
    }

    func test_start_withSavedAddress_loadsItWithoutPrompting() async {
        let defaults = makeIsolatedDefaults()
        WatchAddressStore(defaults: defaults).save(testWallet)

        let repo = StubPortfolioRepository()
        repo.positionsResult = [makePosition()]
        repo.valueResult = 42
        let vm = makeViewModel(repo: repo, defaults: defaults).0

        await vm.start()

        guard case .loaded(let portfolio) = vm.state else {
            return XCTFail("expected .loaded, got \(vm.state)")
        }
        XCTAssertEqual(portfolio.value, 42)
        XCTAssertEqual(vm.address, testWallet)
    }

    // MARK: - Submitting an address

    func test_submit_withInvalidAddress_setsErrorAndFetchesNothing() async {
        let (vm, repo) = makeViewModel()
        vm.addressInput = "not-a-wallet"

        await vm.submit()

        XCTAssertNotNil(vm.inputError)
        XCTAssertNil(vm.address)
        XCTAssertEqual(repo.positionsCallCount, 0, "must not hit the network on invalid input")
        assertState(vm.state, isNeedsAddress: true)
    }

    func test_submit_withValidAddress_persistsItAndLoads() async {
        let defaults = makeIsolatedDefaults()
        let repo = StubPortfolioRepository()
        repo.positionsResult = [makePosition()]
        let vm = makeViewModel(repo: repo, defaults: defaults).0

        vm.addressInput = testWallet
        await vm.submit()

        XCTAssertNil(vm.inputError)
        XCTAssertEqual(vm.address, testWallet)
        XCTAssertEqual(WatchAddressStore(defaults: defaults).address, testWallet,
                       "a submitted wallet must survive relaunch")
    }

    func test_submit_lowercasesTheAddress() async {
        let defaults = makeIsolatedDefaults()
        let vm = makeViewModel(defaults: defaults).0

        vm.addressInput = "0x" + String(repeating: "AB", count: 20)
        await vm.submit()

        XCTAssertEqual(vm.address, testWallet, "WalletAddress normalises case")
    }

    // MARK: - Load outcomes

    func test_load_withNoPositions_isEmptyNotLoaded() async {
        let repo = StubPortfolioRepository()
        repo.positionsResult = []
        let vm = await loadedViewModel(repo: repo)

        guard case .empty = vm.state else {
            return XCTFail("expected .empty, got \(vm.state)")
        }
    }

    func test_load_whenPortfolioFetchFails_showsFailure() async {
        let repo = StubPortfolioRepository()
        repo.positionsError = StubError.boom
        let vm = await loadedViewModel(repo: repo)

        guard case .failed = vm.state else {
            return XCTFail("expected .failed, got \(vm.state)")
        }
    }

    /// Closed positions are supplementary: losing them hides a section, it doesn't
    /// fail the screen.
    func test_load_whenClosedPositionsFail_stillLoadsTheRest() async {
        let repo = StubPortfolioRepository()
        repo.positionsResult = [makePosition()]
        repo.closedError = StubError.boom
        let vm = await loadedViewModel(repo: repo)

        guard case .loaded = vm.state else {
            return XCTFail("a closed-positions failure must not fail the screen, got \(vm.state)")
        }
        XCTAssertTrue(vm.closedPositions.isEmpty)
    }

    func test_load_populatesClosedPositionsOnSuccess() async {
        let repo = StubPortfolioRepository()
        repo.positionsResult = [makePosition()]
        repo.closedResult = [
            ClosedPosition(id: "c1", title: "M", slug: "m", outcome: "Yes", iconURL: nil,
                           realizedPnl: 2, percentRealizedPnl: 10, timestamp: .init())
        ]
        let vm = await loadedViewModel(repo: repo)

        XCTAssertEqual(vm.closedPositions.count, 1)
    }

    // MARK: - Changing wallet

    func test_changeWallet_clearsPersistedAddressAndReprompts() async {
        let defaults = makeIsolatedDefaults()
        let repo = StubPortfolioRepository()
        repo.positionsResult = [makePosition()]
        let vm = makeViewModel(repo: repo, defaults: defaults).0

        vm.addressInput = testWallet
        await vm.submit()
        XCTAssertNotNil(vm.address)

        vm.changeWallet()

        XCTAssertNil(vm.address)
        XCTAssertEqual(vm.addressInput, "")
        XCTAssertNil(WatchAddressStore(defaults: defaults).address,
                     "changing wallet must not leave the old one on disk")
        assertState(vm.state, isNeedsAddress: true)
    }

    func test_refresh_refetches() async {
        let repo = StubPortfolioRepository()
        repo.positionsResult = [makePosition()]
        let vm = await loadedViewModel(repo: repo)
        let before = repo.positionsCallCount

        await vm.refresh()

        XCTAssertEqual(repo.positionsCallCount, before + 1)
    }

    // MARK: - Helpers

    private func makeViewModel(
        repo: StubPortfolioRepository = StubPortfolioRepository(),
        defaults: UserDefaults? = nil
    ) -> (PortfolioViewModel, StubPortfolioRepository) {
        let vm = PortfolioViewModel(
            fetchPortfolio: FetchPortfolioUseCase(repository: repo),
            fetchClosed: FetchClosedPositionsUseCase(repository: repo),
            addressStore: WatchAddressStore(defaults: defaults ?? makeIsolatedDefaults())
        )
        return (vm, repo)
    }

    /// A view model that has already submitted a valid wallet and finished loading.
    private func loadedViewModel(repo: StubPortfolioRepository) async -> PortfolioViewModel {
        let vm = makeViewModel(repo: repo).0
        vm.addressInput = testWallet
        await vm.submit()
        return vm
    }

    private func assertState(
        _ state: PortfolioViewModel.State, isNeedsAddress: Bool,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        if case .needsAddress = state {
            XCTAssertTrue(isNeedsAddress, "unexpected .needsAddress", file: file, line: line)
        } else {
            XCTAssertFalse(isNeedsAddress, "expected .needsAddress, got \(state)", file: file, line: line)
        }
    }
}

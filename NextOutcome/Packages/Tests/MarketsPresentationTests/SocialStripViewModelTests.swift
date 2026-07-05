import XCTest
@testable import MarketsPresentation
import MarketsDomain
import SharedDomain

/// Deterministic gate that never resolves on its own — used to hold a fetch open so a
/// test can cancel its enclosing `Task` mid-flight and observe cancellation actually
/// propagate as a thrown error (rather than the fetch racing to completion first).
/// Mirrors the `Gate` pattern in `EventChartViewModelTests.swift`, but throwing so
/// `Task.cancel()` surfaces as `CancellationError` via `withTaskCancellationHandler`.
private actor CancellableGate {
    private var continuation: CheckedContinuation<Void, Error>?
    private var isCancelled = false

    func wait() async throws {
        if isCancelled { throw CancellationError() }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.continuation = continuation
            }
        } onCancel: {
            Task { await self.cancel() }
        }
    }

    private func cancel() {
        isCancelled = true
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }
}

/// Configurable stub repository — one lever per social-strip endpoint so tests can
/// assert lazy fetch counts and failure paths independently.
private final class SocialStripStubRepository: MarketRepository {
    var comments: [Comment] = []
    var holders: [Holder] = []
    var trades: [ActivityTrade] = []
    var commentsError: Error?
    var holdersError: Error?
    var tradesError: Error?
    var commentsGate: CancellableGate?
    private(set) var commentsCallCount = 0
    private(set) var holdersCallCount = 0
    private(set) var tradesCallCount = 0

    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> { Page(items: [], nextCursor: nil) }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
    func fetchEvent(slug: String) async throws -> Event { throw URLError(.unknown) }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }

    func holders(conditionId: String) async throws -> [Holder] {
        holdersCallCount += 1
        if let holdersError { throw holdersError }
        return holders
    }

    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] {
        commentsCallCount += 1
        if let commentsGate {
            try await commentsGate.wait()
        }
        if let commentsError { throw commentsError }
        return comments
    }

    func trades(conditionId: String) async throws -> [ActivityTrade] {
        tradesCallCount += 1
        if let tradesError { throw tradesError }
        return trades
    }
}

@MainActor
final class SocialStripViewModelTests: XCTestCase {
    private func makeVM(_ repo: SocialStripStubRepository, conditionId: String? = "cond-1") -> SocialStripViewModel {
        SocialStripViewModel(
            eventID: "evt-1",
            conditionId: conditionId,
            fetchComments: FetchCommentsUseCase(repository: repo),
            fetchHolders: FetchHoldersUseCase(repository: repo),
            fetchActivity: FetchActivityTradesUseCase(repository: repo),
            fetchCommenterPositions: FetchCommenterPositionsUseCase(repository: repo)
        )
    }

    func test_initialState_allTabsIdle() {
        let vm = makeVM(SocialStripStubRepository())
        guard case .idle = vm.commentsState else { return XCTFail("expected .idle") }
        guard case .idle = vm.holdersState else { return XCTFail("expected .idle") }
        guard case .idle = vm.activityState else { return XCTFail("expected .idle") }
    }

    func test_loadIfNeeded_onlyFetchesTheRequestedTab() async {
        let repo = SocialStripStubRepository()
        repo.comments = [Comment(id: "1", authorName: "A", avatarURL: nil, createdAt: nil, body: "hi")]
        let vm = makeVM(repo)

        await vm.loadIfNeeded(.comments)

        XCTAssertEqual(repo.commentsCallCount, 1)
        XCTAssertEqual(repo.holdersCallCount, 0)
        XCTAssertEqual(repo.tradesCallCount, 0)
        guard case .loaded(let items) = vm.commentsState else { return XCTFail("expected .loaded") }
        XCTAssertEqual(items.count, 1)
        guard case .idle = vm.holdersState else { return XCTFail("holders must stay idle until visited") }
    }

    func test_loadIfNeeded_calledTwice_onlyFetchesOnce() async {
        let repo = SocialStripStubRepository()
        repo.holders = [Holder(id: "h1", name: "Whale", profileImageURL: nil, outcome: "Yes", shares: 100)]
        let vm = makeVM(repo)

        await vm.loadIfNeeded(.holders)
        await vm.loadIfNeeded(.holders) // second "visit" — must not re-fetch

        XCTAssertEqual(repo.holdersCallCount, 1)
        guard case .loaded = vm.holdersState else { return XCTFail("expected .loaded") }
    }

    func test_loadIfNeeded_emptyResult_setsEmptyState() async {
        let repo = SocialStripStubRepository()
        let vm = makeVM(repo)

        await vm.loadIfNeeded(.activity)

        guard case .empty = vm.activityState else { return XCTFail("expected .empty, got \(vm.activityState)") }
    }

    func test_loadIfNeeded_failure_setsFailedStateWithMessage() async {
        let repo = SocialStripStubRepository()
        repo.commentsError = URLError(.notConnectedToInternet)
        let vm = makeVM(repo)

        await vm.loadIfNeeded(.comments)

        guard case .failed(let message) = vm.commentsState else { return XCTFail("expected .failed") }
        XCTAssertFalse(message.isEmpty)
    }

    func test_retry_afterFailure_refetchesAndCanSucceed() async {
        let repo = SocialStripStubRepository()
        repo.holdersError = URLError(.timedOut)
        let vm = makeVM(repo)

        await vm.loadIfNeeded(.holders)
        guard case .failed = vm.holdersState else { return XCTFail("expected .failed before retry") }

        repo.holdersError = nil
        repo.holders = [Holder(id: "h1", name: "Whale", profileImageURL: nil, outcome: "Yes", shares: 100)]
        await vm.retry(.holders)

        XCTAssertEqual(repo.holdersCallCount, 2)
        guard case .loaded(let items) = vm.holdersState else { return XCTFail("expected .loaded after retry") }
        XCTAssertEqual(items.count, 1)
    }

    func test_positionsTab_neverFetches_staysIdle() async {
        let repo = SocialStripStubRepository()
        let vm = makeVM(repo)

        await vm.loadIfNeeded(.positions)

        XCTAssertEqual(repo.commentsCallCount, 0)
        XCTAssertEqual(repo.holdersCallCount, 0)
        XCTAssertEqual(repo.tradesCallCount, 0)
    }

    /// Regression test: `SocialStripView` drives fetches via `.task(id: selectedTab)`,
    /// which SwiftUI cancels when the user switches tabs mid-fetch. Cancellation must
    /// reset the tab to `.idle`, not `.failed` — otherwise the tab is stuck showing a
    /// bogus "connection error" retry row until the app restarts.
    func test_cancelledFetch_resetsToIdle_notFailed() async {
        let repo = SocialStripStubRepository()
        let gate = CancellableGate()
        repo.commentsGate = gate
        let vm = makeVM(repo)

        let task = Task { await vm.loadIfNeeded(.comments) }
        while repo.commentsCallCount == 0 { await Task.yield() } // let the fetch actually start and hit the gate
        task.cancel()
        await task.value

        guard case .idle = vm.commentsState else {
            return XCTFail("expected .idle after cancellation, got \(vm.commentsState)")
        }
    }

    func test_cancelledThenRevisited_refetches() async {
        let repo = SocialStripStubRepository()
        let gate = CancellableGate()
        repo.commentsGate = gate
        let vm = makeVM(repo)

        let task = Task { await vm.loadIfNeeded(.comments) }
        while repo.commentsCallCount == 0 { await Task.yield() }
        task.cancel()
        await task.value
        guard case .idle = vm.commentsState else {
            return XCTFail("expected .idle after cancellation, got \(vm.commentsState)")
        }

        repo.commentsGate = nil
        repo.comments = [Comment(id: "1", authorName: "A", avatarURL: nil, createdAt: nil, body: "hi")]
        await vm.loadIfNeeded(.comments)

        XCTAssertEqual(repo.commentsCallCount, 2)
        guard case .loaded(let items) = vm.commentsState else {
            return XCTFail("expected .loaded, got \(vm.commentsState)")
        }
        XCTAssertEqual(items.count, 1)
    }

    func test_holdersAndActivity_withoutConditionId_resolveEmptyWithoutFetching() async {
        let repo = SocialStripStubRepository()
        let vm = makeVM(repo, conditionId: nil)

        await vm.loadIfNeeded(.holders)
        await vm.loadIfNeeded(.activity)

        XCTAssertEqual(repo.holdersCallCount, 0)
        XCTAssertEqual(repo.tradesCallCount, 0)
        guard case .empty = vm.holdersState else { return XCTFail("expected .empty") }
        guard case .empty = vm.activityState else { return XCTFail("expected .empty") }
    }
}

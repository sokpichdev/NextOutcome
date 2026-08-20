import Foundation
import SharedDomain
@testable import PortfolioDomain

/// Errors the stubs throw when a test asks them to fail.
enum StubError: Error { case boom }

/// A `PortfolioRepository` whose every response is configurable per test, and which
/// records the arguments it was called with so tests can assert on *what was asked for*,
/// not just what came back.
///
/// A class (not a struct) so recorded calls survive being captured by the use cases.
///
/// Every touch of the mutable state goes through `lock`, because callers reach this from
/// several tasks at once and the `@unchecked Sendable` is otherwise a lie.
/// `LeaderboardViewModel` is the routine offender: it is `@MainActor`, but
/// `FetchLeaderboardUseCase` and this protocol are both nonisolated, so each `load()` hops
/// onto the cooperative pool — and its `metric`/`window` `didSet` handlers spawn one
/// `load()` per assignment, so a test that sets both and then calls `load()` has three
/// tasks appending to `leaderboardCalls` at once. Unsynchronised, that raced on the array's
/// buffer and killed the whole suite with SIGABRT/SIGSEGV/SIGILL in ~30% of runs, on both
/// x86_64 and the arm64 CI runner. Same treatment, same reason, as
/// `FakeCryptoSpotPriceRepository` in the Orderbook suite.
///
/// `PortfolioStubsTests` holds this to that promise.
final class StubPortfolioRepository: PortfolioRepository, @unchecked Sendable {
    private let lock = NSLock()

    // Canned responses. `nil` on a `*Error` means "succeed".
    private var _positionsResult: [Position] = []
    var positionsResult: [Position] {
        get { lock.withLock { _positionsResult } }
        set { lock.withLock { _positionsResult = newValue } }
    }

    private var _valueResult: Decimal = 0
    var valueResult: Decimal {
        get { lock.withLock { _valueResult } }
        set { lock.withLock { _valueResult = newValue } }
    }

    private var _closedResult: [ClosedPosition] = []
    var closedResult: [ClosedPosition] {
        get { lock.withLock { _closedResult } }
        set { lock.withLock { _closedResult = newValue } }
    }

    private var _leaderboardResult: [LeaderboardEntry] = []
    var leaderboardResult: [LeaderboardEntry] {
        get { lock.withLock { _leaderboardResult } }
        set { lock.withLock { _leaderboardResult = newValue } }
    }

    private var _positionsError: Error?
    var positionsError: Error? {
        get { lock.withLock { _positionsError } }
        set { lock.withLock { _positionsError = newValue } }
    }

    private var _valueError: Error?
    var valueError: Error? {
        get { lock.withLock { _valueError } }
        set { lock.withLock { _valueError = newValue } }
    }

    private var _closedError: Error?
    var closedError: Error? {
        get { lock.withLock { _closedError } }
        set { lock.withLock { _closedError = newValue } }
    }

    private var _leaderboardError: Error?
    var leaderboardError: Error? {
        get { lock.withLock { _leaderboardError } }
        set { lock.withLock { _leaderboardError = newValue } }
    }

    // Recorded calls.
    private var _leaderboardCalls: [(metric: LeaderboardMetric,
                                     window: LeaderboardWindow,
                                     category: String?,
                                     limit: Int)] = []
    private(set) var leaderboardCalls: [(metric: LeaderboardMetric,
                                         window: LeaderboardWindow,
                                         category: String?,
                                         limit: Int)] {
        get { lock.withLock { _leaderboardCalls } }
        set { lock.withLock { _leaderboardCalls = newValue } }
    }

    private var _positionsCallCount = 0
    private(set) var positionsCallCount: Int {
        get { lock.withLock { _positionsCallCount } }
        set { lock.withLock { _positionsCallCount = newValue } }
    }

    private var _closedCallCount = 0
    private(set) var closedCallCount: Int {
        get { lock.withLock { _closedCallCount } }
        set { lock.withLock { _closedCallCount = newValue } }
    }

    func positions(address: String) async throws -> [Position] {
        // Bump the counter and read the canned error under one acquisition: taking the
        // lock twice would let a concurrent caller interleave between them.
        let error: Error? = lock.withLock {
            _positionsCallCount += 1
            return _positionsError
        }
        if let error { throw error }
        return positionsResult
    }

    func value(address: String) async throws -> Decimal {
        if let valueError { throw valueError }
        return valueResult
    }

    func activity(address: String, cursor: String?) async throws -> Page<Activity> {
        Page(items: [], nextCursor: nil)
    }

    func closedPositions(address: String) async throws -> [ClosedPosition] {
        let error: Error? = lock.withLock {
            _closedCallCount += 1
            return _closedError
        }
        if let error { throw error }
        return closedResult
    }

    func leaderboard(
        metric: LeaderboardMetric, window: LeaderboardWindow, category: String?, limit: Int
    ) async throws -> [LeaderboardEntry] {
        let error: Error? = lock.withLock {
            _leaderboardCalls.append((metric, window, category, limit))
            return _leaderboardError
        }
        if let error { throw error }
        return leaderboardResult
    }
}

// MARK: - Fixtures

/// A valid 40-hex-character wallet address.
let testWallet = "0x" + String(repeating: "ab", count: 20)

func makePosition(cashPnl: Decimal = 1) -> Position {
    Position(id: "t", conditionId: "c", title: "M", slug: "m", outcome: "Yes",
             iconURL: nil, size: 10, avgPrice: 0.5, curPrice: 0.6,
             currentValue: 6, cashPnl: cashPnl, percentPnl: 20, redeemable: false)
}

func makeEntry(rank: Int = 1) -> LeaderboardEntry {
    LeaderboardEntry(id: "u\(rank)", rank: rank, name: "Trader \(rank)",
                     profileImageURL: nil, amount: 100)
}

/// A `UserDefaults` isolated to one test, so the watch-address store never leaks state
/// between tests or touches the real `.standard` domain.
func makeIsolatedDefaults() -> UserDefaults {
    UserDefaults(suiteName: "PortfolioPresentationTests.\(UUID().uuidString)")!
}

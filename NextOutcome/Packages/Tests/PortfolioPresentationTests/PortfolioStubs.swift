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
final class StubPortfolioRepository: PortfolioRepository, @unchecked Sendable {
    // Canned responses. `nil` on a `*Error` means "succeed".
    var positionsResult: [Position] = []
    var valueResult: Decimal = 0
    var closedResult: [ClosedPosition] = []
    var leaderboardResult: [LeaderboardEntry] = []

    var positionsError: Error?
    var valueError: Error?
    var closedError: Error?
    var leaderboardError: Error?

    // Recorded calls.
    private(set) var leaderboardCalls: [(metric: LeaderboardMetric,
                                         window: LeaderboardWindow,
                                         category: String?,
                                         limit: Int)] = []
    private(set) var positionsCallCount = 0
    private(set) var closedCallCount = 0

    func positions(address: String) async throws -> [Position] {
        positionsCallCount += 1
        if let positionsError { throw positionsError }
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
        closedCallCount += 1
        if let closedError { throw closedError }
        return closedResult
    }

    func leaderboard(
        metric: LeaderboardMetric, window: LeaderboardWindow, category: String?, limit: Int
    ) async throws -> [LeaderboardEntry] {
        leaderboardCalls.append((metric, window, category, limit))
        if let leaderboardError { throw leaderboardError }
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

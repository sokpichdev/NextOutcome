//
//  PortfolioStubsTests.swift
//  NextOutcome
//

import XCTest
@testable import PortfolioDomain

/// Holds `StubPortfolioRepository` to the promise its `@unchecked Sendable` makes.
///
/// `@unchecked Sendable` tells the compiler "trust me, this is safe from several tasks at
/// once" and switches off the checking that would otherwise prove it. When that promise is
/// false the failure is not a test failure — it is heap corruption that takes the whole
/// process down, at whatever unrelated allocation happens to notice first.
///
/// `LeaderboardViewModel` is what makes concurrent use routine rather than theoretical: it
/// is `@MainActor`, but `FetchLeaderboardUseCase` and `PortfolioRepository` are both
/// nonisolated, so each `load()` hops onto the cooperative pool — and its `metric`/`window`
/// `didSet` handlers spawn one `load()` per assignment. Two assignments plus an explicit
/// `load()` is three tasks appending to the same array.
///
/// That raced on the recording array's buffer and killed the suite with
/// SIGABRT/SIGSEGV/SIGILL in roughly 30% of runs, on both x86_64 and the arm64 CI runner.
final class PortfolioStubsTests: XCTestCase {
    /// Fires many concurrent `leaderboard` calls and insists every one was recorded.
    ///
    /// A dropped append is the benign symptom of the race; corruption is the malignant one.
    /// Asserting on the count catches the former without depending on the latter, which is
    /// not something a test can assert on — it just ends the process.
    func test_stubRepository_recordsEveryCall_whenHitConcurrently() async {
        let repo = StubPortfolioRepository()
        let callCount = 500

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<callCount {
                group.addTask {
                    _ = try? await repo.leaderboard(
                        metric: .volume, window: .week, category: nil, limit: 10
                    )
                }
            }
        }

        XCTAssertEqual(
            repo.leaderboardCalls.count, callCount,
            "the double dropped calls under concurrency — its mutable state is not synchronised"
        )
    }

    /// The same promise for the two counter-based recordings, which race identically.
    func test_stubRepository_countsEveryCall_whenHitConcurrently() async {
        let repo = StubPortfolioRepository()
        let callCount = 500

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<callCount {
                group.addTask { _ = try? await repo.positions(address: testWallet) }
                group.addTask { _ = try? await repo.closedPositions(address: testWallet) }
            }
        }

        XCTAssertEqual(repo.positionsCallCount, callCount)
        XCTAssertEqual(repo.closedCallCount, callCount)
    }
}

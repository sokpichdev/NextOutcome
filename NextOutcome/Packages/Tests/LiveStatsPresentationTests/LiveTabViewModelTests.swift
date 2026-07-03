import XCTest
@testable import LiveStatsPresentation
import LiveStatsDomain

private struct StubStreamer: SportsStateStreaming {
    let build: @Sendable (AsyncThrowingStream<MatchState, Error>.Continuation) -> Void
    func states(gameID: String) -> AsyncThrowingStream<MatchState, Error> {
        AsyncThrowingStream { continuation in build(continuation) }
    }
}

@MainActor
final class LiveTabViewModelTests: XCTestCase {
    private func waitFor(_ predicate: @escaping () -> Bool) async {
        for _ in 0..<200 where !predicate() {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    func testStreamEmissionUpdatesState() async {
        let snapshot = MatchState(gameID: "g", period: "1H", isLive: true,
                                  home: .init(goals: 1), away: .init(goals: 0))
        let vm = LiveTabViewModel(gameID: "g", streamer: StubStreamer { c in
            c.yield(snapshot); c.finish()
        })
        vm.start()
        await waitFor { vm.match != nil }
        XCTAssertEqual(vm.match?.home.goals, 1)
        XCTAssertEqual(vm.connection, .live)
    }

    func testNilLineupsYieldsUnavailableSection() async {
        let snapshot = MatchState(gameID: "g", isLive: true) // no lineups
        let vm = LiveTabViewModel(gameID: "g", streamer: StubStreamer { c in
            c.yield(snapshot); c.finish()
        })
        vm.start()
        await waitFor { vm.match != nil }
        XCTAssertEqual(vm.availability(of: .lineups), .unavailable)
        XCTAssertEqual(vm.availability(of: .h2h), .unavailable)
    }

    func testStreamErrorGoesToFailedThenRetryRecovers() async {
        let box = ResultBox()
        let vm = LiveTabViewModel(gameID: "g", streamer: StubStreamer { c in
            if box.shouldFail {
                box.shouldFail = false
                c.finish(throwing: URLError(.timedOut))
            } else {
                c.yield(MatchState(gameID: "g", isLive: true)); c.finish()
            }
        })
        vm.start()
        await waitFor { if case .failed = vm.state { return true }; return false }
        guard case .failed = vm.state else { return XCTFail("expected .failed") }

        vm.retry()
        await waitFor { vm.match != nil }
        XCTAssertNotNil(vm.match)
    }
}

private final class ResultBox: @unchecked Sendable {
    var shouldFail = true
}

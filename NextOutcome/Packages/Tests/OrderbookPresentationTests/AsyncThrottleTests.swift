import XCTest
@testable import OrderbookPresentation

final class AsyncThrottleTests: XCTestCase {
    /// A burst faster than the interval collapses to a handful of emissions — and the last
    /// value still arrives, which is what stops a stalled feed leaving stale prices on screen.
    func testBurstCollapsesButStillDeliversTheNewestValue() async {
        let source = AsyncStream<Int> { continuation in
            for value in 0..<200 { continuation.yield(value) }
            continuation.finish()
        }

        var received: [Int] = []
        for await value in source.throttled(for: .milliseconds(50)) {
            received.append(value)
        }

        XCTAssertLessThan(received.count, 10, "200 values in a burst should coalesce, got \(received)")
        XCTAssertEqual(received.last, 199)
    }

    /// A producer slower than the interval is passed through untouched: throttling must not
    /// drop or delay values on a quiet feed.
    func testSlowProducerPassesEveryValueThrough() async {
        let source = AsyncStream<Int> { continuation in
            Task {
                for value in 0..<3 {
                    continuation.yield(value)
                    try? await Task.sleep(for: .milliseconds(60))
                }
                continuation.finish()
            }
        }

        var received: [Int] = []
        for await value in source.throttled(for: .milliseconds(10)) {
            received.append(value)
        }

        XCTAssertEqual(received, [0, 1, 2])
    }

    /// The throttled stream finishes when upstream does, so a view model's `for await` loop
    /// exits on teardown instead of leaking a parked task.
    func testFinishesWhenUpstreamFinishes() async {
        let source = AsyncStream<Int> { $0.finish() }

        var received: [Int] = []
        for await value in source.throttled(for: .milliseconds(10)) {
            received.append(value)
        }

        XCTAssertTrue(received.isEmpty)
    }

    /// Breaking out of the loop tears the upstream subscription down rather than leaving the
    /// socket task draining forever.
    func testCancellingTheConsumerTerminatesUpstream() async {
        let terminated = Expectation()
        let source = AsyncStream<Int> { continuation in
            continuation.onTermination = { _ in Task { await terminated.fulfil() } }
            Task {
                while !Task.isCancelled {
                    continuation.yield(1)
                    try? await Task.sleep(for: .milliseconds(5))
                }
            }
        }

        for await _ in source.throttled(for: .milliseconds(5)) { break }

        try? await Task.sleep(for: .milliseconds(100))
        let didTerminate = await terminated.isFulfilled
        XCTAssertTrue(didTerminate)
    }
}

/// A tiny async flag, since `XCTestExpectation` can't be fulfilled from an actor-isolated
/// context without hopping back.
private actor Expectation {
    private(set) var isFulfilled = false
    func fulfil() { isFulfilled = true }
}

import XCTest
import OrderbookDomain
@testable import OrderbookData

/// Counts subscriptions and lets a test push events into every one of them.
private final class FakeMarketStream: MarketStreaming, @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [AsyncStream<OrderBookEvent>.Continuation] = []
    private(set) var subscriptionCount = 0
    private(set) var cancelledCount = 0

    func events(assetID: String) -> AsyncStream<OrderBookEvent> {
        AsyncStream { continuation in
            lock.lock()
            subscriptionCount += 1
            continuations.append(continuation)
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                lock.lock(); cancelledCount += 1; lock.unlock()
            }
        }
    }

    func send(_ event: OrderBookEvent) {
        lock.lock()
        let targets = continuations
        lock.unlock()
        targets.forEach { $0.yield(event) }
    }
}

final class SharedMarketStreamTests: XCTestCase {
    /// The point of the decorator: one screen watching a token twice must open one socket.
    func testTwoConsumersOfOneTokenShareASingleUpstreamSubscription() async throws {
        let upstream = FakeMarketStream()
        let shared = SharedMarketStream(upstream: upstream)

        let first = shared.events(assetID: "token-1").makeAsyncIterator()
        let second = shared.events(assetID: "token-1").makeAsyncIterator()
        _ = first; _ = second
        try await settle()

        XCTAssertEqual(upstream.subscriptionCount, 1)
    }

    /// Sharing is worthless if the late joiner doesn't see the feed.
    func testEveryConsumerReceivesEveryEvent() async throws {
        let upstream = FakeMarketStream()
        let shared = SharedMarketStream(upstream: upstream)

        let firstReceived = Collector()
        let secondReceived = Collector()
        let firstTask = Task {
            for await event in shared.events(assetID: "token-1") {
                await firstReceived.append(event)
            }
        }
        let secondTask = Task {
            for await event in shared.events(assetID: "token-1") {
                await secondReceived.append(event)
            }
        }
        try await settle()

        upstream.send(.connectionState(.live))
        try await settle()

        let first = await firstReceived.events
        let second = await secondReceived.events
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(second.count, 1)

        firstTask.cancel()
        secondTask.cancel()
    }

    /// Different tokens are different books: they must not be collapsed onto one feed.
    func testDifferentTokensGetTheirOwnSubscriptions() async throws {
        let upstream = FakeMarketStream()
        let shared = SharedMarketStream(upstream: upstream)

        let first = shared.events(assetID: "token-1").makeAsyncIterator()
        let second = shared.events(assetID: "token-2").makeAsyncIterator()
        _ = first; _ = second
        try await settle()

        XCTAssertEqual(upstream.subscriptionCount, 2)
    }

    /// The last consumer leaving must close the socket, or every visited market leaks a
    /// connection for the rest of the session.
    func testUpstreamIsTornDownWhenTheLastConsumerLeaves() async throws {
        let upstream = FakeMarketStream()
        let shared = SharedMarketStream(upstream: upstream)

        var streams: [AsyncStream<OrderBookEvent>]? = [
            shared.events(assetID: "token-1"),
            shared.events(assetID: "token-1"),
        ]
        try await settle()
        XCTAssertEqual(upstream.cancelledCount, 0)

        streams = nil
        _ = streams
        try await settle()

        XCTAssertEqual(upstream.cancelledCount, 1)
    }

    /// A consumer that joins after the socket connected still gets to show "live" rather
    /// than an empty indicator it can only fix by waiting for a reconnect.
    func testLateJoinerGetsTheCurrentConnectionStateReplayed() async throws {
        let upstream = FakeMarketStream()
        let shared = SharedMarketStream(upstream: upstream)

        let earlyTask = Task {
            for await _ in shared.events(assetID: "token-1") {}
        }
        try await settle()
        upstream.send(.connectionState(.live))
        try await settle()

        let received = Collector()
        let lateTask = Task {
            for await event in shared.events(assetID: "token-1") {
                await received.append(event)
            }
        }
        try await settle()

        let events = await received.events
        XCTAssertEqual(events.count, 1)
        if case let .connectionState(state) = events.first {
            XCTAssertEqual(state, .live)
        } else {
            XCTFail("expected the connection state to be replayed, got \(events)")
        }

        earlyTask.cancel()
        lateTask.cancel()
    }

    /// Lets the actor hops behind `attach`/`broadcast` land.
    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(40))
    }
}

private actor Collector {
    private(set) var events: [OrderBookEvent] = []
    func append(_ event: OrderBookEvent) { events.append(event) }
}

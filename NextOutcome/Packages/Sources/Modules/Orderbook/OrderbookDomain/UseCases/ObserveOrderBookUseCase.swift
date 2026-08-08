//
//  ObserveOrderBookUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

/// Streams fully-reconciled `OrderBook` states: seeds with the REST snapshot,
/// then folds live socket events through the pure reducer.
public struct ObserveOrderBookUseCase: Sendable {
    /// The REST source used to seed the initial snapshot.
    private let repository: OrderbookRepository
    /// The realtime source of incremental book events.
    private let stream: MarketStreaming

    /// Creates the use case.
    /// - Parameters:
    ///   - repository: Supplies the initial REST snapshot.
    ///   - stream: Supplies live socket events.
    public init(repository: OrderbookRepository, stream: MarketStreaming) {
        self.repository = repository
        self.stream = stream
    }

    /// Streams reconciled order-book states for one token.
    ///
    /// Yields an immediate snapshot (so the UI isn't blank), then a new fully-reconciled
    /// book each time a socket event arrives. Cancelling the consuming task tears down the
    /// subscription.
    /// - Parameter assetID: The token to observe.
    /// - Returns: An async stream of successive `OrderBook` states.
    public func execute(assetID: String) -> AsyncStream<OrderBook> {
        AsyncStream { continuation in
            let task = Task {
                var book = OrderBook(assetID: assetID)

                // Seed with a REST snapshot so the UI has data immediately.
                if let snapshot = try? await repository.book(assetID: assetID) {
                    book = snapshot
                    continuation.yield(book)
                }

                for await event in stream.events(assetID: assetID) {
                    book = OrderBookReducer.reduce(book, event)
                    continuation.yield(book)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

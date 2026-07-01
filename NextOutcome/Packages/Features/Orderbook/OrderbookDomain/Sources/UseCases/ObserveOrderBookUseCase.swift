//
//  ObserveOrderBookUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

/// Streams fully-reconciled `OrderBook` states: seeds with the REST snapshot,
/// then folds live socket events through the pure reducer.
public struct ObserveOrderBookUseCase: Sendable {
    private let repository: OrderbookRepository
    private let stream: MarketStreaming

    public init(repository: OrderbookRepository, stream: MarketStreaming) {
        self.repository = repository
        self.stream = stream
    }

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

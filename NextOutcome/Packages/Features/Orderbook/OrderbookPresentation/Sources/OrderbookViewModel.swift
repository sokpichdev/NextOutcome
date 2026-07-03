//
//  OrderbookViewModel.swift
//  NextOutcome
//

import Foundation
import OrderbookDomain
import SharedDomain

/// Drives `OrderbookView`: seeds with the REST `book()` snapshot, then folds live
/// socket deltas into the `BookLadder` on the main actor. Connection lifecycle
/// (`connecting` / `live` / `reconnecting`) is *observed* from `MarketSocket`'s own
/// events — this view model never reimplements backoff/reconnect timing.
@MainActor
@Observable
public final class OrderbookViewModel {
    public private(set) var state: LoadState<BookLadder> = .idle
    public private(set) var connection: ConnectionState = .connecting
    public var expanded: Bool = false

    private let assetID: String
    private let repository: OrderbookRepository
    private let stream: MarketStreaming
    private var streamTask: Task<Void, Never>?

    public init(assetID: String, repository: OrderbookRepository, stream: MarketStreaming) {
        self.assetID = assetID
        self.repository = repository
        self.stream = stream
    }

    public func start() {
        guard streamTask == nil else { return }
        state = .loading
        connection = .connecting
        streamTask = Task { [weak self] in
            await self?.run()
        }
    }

    public func stop() {
        streamTask?.cancel()
        streamTask = nil
    }

    public func toggleExpanded() {
        expanded.toggle()
    }

    /// Resets to `.idle` and restarts the whole pipeline (REST seed + socket).
    /// Used by the inline retry row after a failed initial fetch.
    public func retry() async {
        stop()
        start()
    }

    private func run() async {
        do {
            let book = try await repository.book(assetID: assetID)
            state = .loaded(BookLadder.from(book))
        } catch {
            if isCancellation(error) {
                state = .idle
            } else {
                state = .failed(message: "Couldn't load order book. Check your connection and try again.")
            }
            return
        }

        for await event in stream.events(assetID: assetID) {
            guard !Task.isCancelled else { break }
            apply(event)
        }
    }

    private func apply(_ event: OrderBookEvent) {
        switch event {
        case let .snapshot(bids, asks, _, _):
            let book = OrderBook(assetID: assetID, bids: bids, asks: asks)
            state = .loaded(BookLadder.from(book))

        case let .priceChanges(changes):
            guard case let .loaded(ladder) = state else { return }
            state = .loaded(changes.reduce(ladder) { $0.applying($1) })

        case .lastTrade, .tickSize:
            break // not part of the ladder

        case let .connectionState(newState):
            connection = newState
        }
    }

    /// A cancelled fetch (e.g. the view disappearing mid-load) is not a network
    /// failure — see `SocialStripViewModel.isCancellation` for the same pattern.
    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if (error as? URLError)?.code == .cancelled { return true }
        return Task.isCancelled
    }
}

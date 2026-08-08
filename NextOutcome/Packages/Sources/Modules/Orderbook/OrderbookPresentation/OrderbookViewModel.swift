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
    /// The order book to render, wrapped in a load state so errors have somewhere to go.
    public private(set) var state: LoadState<BookLadder> = .idle
    /// The socket connection status, shown as a small indicator in the UI.
    public private(set) var connection: ConnectionState = .connecting
    /// Whether the view is showing the expanded (more levels) layout.
    public var expanded: Bool = false

    /// The token whose book this view model streams.
    private let assetID: String
    /// Supplies the initial REST snapshot.
    private let repository: OrderbookRepository
    /// Supplies live socket deltas.
    private let stream: MarketStreaming
    /// The running subscription task; `nil` when stopped.
    private var streamTask: Task<Void, Never>?

    /// Creates the view model.
    /// - Parameters:
    ///   - assetID: The token to stream.
    ///   - repository: The REST source for the seed snapshot.
    ///   - stream: The realtime source for deltas.
    public init(assetID: String, repository: OrderbookRepository, stream: MarketStreaming) {
        self.assetID = assetID
        self.repository = repository
        self.stream = stream
    }

    /// Begins loading: fetches the seed snapshot then subscribes to live deltas. Safe to
    /// call more than once — a second call while already running is ignored.
    public func start() {
        guard streamTask == nil else { return }
        state = .loading
        connection = .connecting
        streamTask = Task { [weak self] in
            await self?.run()
        }
    }

    /// Cancels the subscription and clears the running task. Call from the view's teardown.
    public func stop() {
        streamTask?.cancel()
        streamTask = nil
    }

    /// Flips between the compact and expanded book layouts.
    public func toggleExpanded() {
        expanded.toggle()
    }

    /// Resets to `.idle` and restarts the whole pipeline (REST seed + socket).
    /// Used by the inline retry row after a failed initial fetch.
    public func retry() async {
        stop()
        start()
    }

    /// The subscription body: seed with a REST snapshot, then fold each socket event into
    /// the ladder until cancelled. A cancelled initial fetch resets to `.idle` (not an
    /// error); any other failure surfaces a retry message.
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

    /// Folds one socket event into the current state: replacing the ladder on a snapshot,
    /// applying incremental changes, or updating the connection indicator.
    /// - Parameter event: The incoming normalized event.
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

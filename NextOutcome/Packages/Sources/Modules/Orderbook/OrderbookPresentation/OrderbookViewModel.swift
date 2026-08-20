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
    /// How often the folded ladder may republish into `@Observable` state.
    /// See `LiveFeedRate.ladder`.
    private let updateInterval: Duration
    /// The running subscription task; `nil` when stopped.
    private var streamTask: Task<Void, Never>?

    /// Creates the view model.
    /// - Parameters:
    ///   - assetID: The token to stream.
    ///   - repository: The REST source for the seed snapshot.
    ///   - stream: The realtime source for deltas.
    ///   - updateInterval: How often the folded ladder republishes to the UI. Pass `.zero`
    ///     to publish every delta (tests, which can't wait out a wall-clock cooldown).
    public init(
        assetID: String,
        repository: OrderbookRepository,
        stream: MarketStreaming,
        updateInterval: Duration = LiveFeedRate.ladder
    ) {
        self.assetID = assetID
        self.repository = repository
        self.stream = stream
        self.updateInterval = updateInterval
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
    ///
    /// Folding and *publishing* are deliberately separated. Every delta has to be folded —
    /// they're incremental, so skipping one corrupts the ladder — but a busy market sends
    /// them faster than anyone can read twenty rows of depth, and each publish re-renders
    /// the whole ladder. So the fold runs at socket rate into a private ladder and only the
    /// result is published, at `updateInterval`.
    private func run() async {
        var ladder: BookLadder
        do {
            let book = try await repository.book(assetID: assetID)
            ladder = BookLadder.from(book)
            state = .loaded(ladder)
        } catch {
            if isCancellation(error) {
                state = .idle
            } else {
                state = .failed(message: "Couldn't load order book. Check your connection and try again.")
            }
            return
        }

        let (ladders, publish) = AsyncStream<BookLadder>.makeStream()
        Task { [weak self, updateInterval] in
            for await ladder in ladders.throttled(for: updateInterval) {
                self?.state = .loaded(ladder)
            }
        }
        // Finishing (rather than cancelling) lets the throttle deliver its pending ladder
        // before the publishing task ends, so the last state the socket sent still lands.
        defer { publish.finish() }

        for await event in stream.events(assetID: assetID) {
            guard !Task.isCancelled else { break }
            switch event {
            case let .snapshot(bids, asks, _, _):
                ladder = BookLadder.from(OrderBook(assetID: assetID, bids: bids, asks: asks))
                publish.yield(ladder)

            case let .priceChanges(changes):
                ladder = changes.reduce(ladder) { $0.applying($1) }
                publish.yield(ladder)

            case .lastTrade, .tickSize:
                break // not part of the ladder

            case let .connectionState(newState):
                // Published immediately rather than through the throttle: state changes are
                // rare, and coalescing one away would leave the indicator lying.
                if connection != newState { connection = newState }
            }
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

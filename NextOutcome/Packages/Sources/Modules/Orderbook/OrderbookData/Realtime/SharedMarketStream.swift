//
//  SharedMarketStream.swift
//  NextOutcome
//
//  Created by Sok Pich on 20/08/2026.
//

import Foundation
import OrderbookDomain

/// Fans one upstream market subscription out to every consumer watching the same token.
///
/// `MarketSocket.events(assetID:)` opens a *connection* per call, and the live crypto screen
/// asks for the same token twice: `BTCLiveViewModel` streams the book for its quick-bet
/// cents and chance series, and the `OrderbookView` embedded in the same screen streams it
/// again for the depth ladder. That was two WebSockets, two sets of frames, and two JSON
/// decodes of identical bytes — all to render one screen.
///
/// This decorator keeps one upstream subscription per token, reference-counted: the first
/// consumer opens it, the last one to walk away closes it. New consumers get the current
/// connection state replayed so their indicator isn't blank, but *not* a stale snapshot —
/// both consumers seed themselves from REST, and a cached snapshot older than that seed
/// would drag the book backwards.
public actor SharedMarketStream: MarketStreaming {
    /// The real socket being shared.
    private let upstream: MarketStreaming
    /// One entry per token with at least one live consumer.
    private var feeds: [String: Feed] = [:]

    /// The shared subscription for one token.
    private struct Feed {
        /// The task draining upstream and re-yielding to every consumer.
        var task: Task<Void, Never>?
        /// The live consumers, keyed so a departing one can be removed by identity.
        var consumers: [UUID: AsyncStream<OrderBookEvent>.Continuation] = [:]
        /// The last connection state seen, replayed to consumers that join later.
        var connection: OrderBookEvent?
    }

    /// Creates the sharing decorator.
    /// - Parameter upstream: The socket to share — normally a `MarketSocket`.
    public init(upstream: MarketStreaming) {
        self.upstream = upstream
    }

    /// Streams book events for one token, joining the shared subscription if one is already
    /// open (see `MarketStreaming`).
    public nonisolated func events(assetID: String) -> AsyncStream<OrderBookEvent> {
        AsyncStream { continuation in
            let id = UUID()
            Task { await attach(id: id, assetID: assetID, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.detach(id: id, assetID: assetID) }
            }
        }
    }

    /// Adds a consumer, opening the upstream subscription if it's the first one.
    private func attach(
        id: UUID,
        assetID: String,
        continuation: AsyncStream<OrderBookEvent>.Continuation
    ) {
        var feed = feeds[assetID] ?? Feed()
        feed.consumers[id] = continuation
        if let connection = feed.connection { continuation.yield(connection) }
        let needsSubscription = feed.task == nil
        feeds[assetID] = feed

        guard needsSubscription else { return }
        let task = Task { [upstream] in
            for await event in upstream.events(assetID: assetID) {
                await broadcast(event, assetID: assetID)
            }
            await closeFeed(assetID: assetID)
        }
        feeds[assetID]?.task = task
    }

    /// Removes a consumer, closing the upstream subscription once the last one leaves.
    private func detach(id: UUID, assetID: String) {
        guard var feed = feeds[assetID] else { return }
        feed.consumers.removeValue(forKey: id)
        guard feed.consumers.isEmpty else {
            feeds[assetID] = feed
            return
        }
        feed.task?.cancel()
        feeds[assetID] = nil
    }

    /// Sends one upstream event to every consumer of that token.
    private func broadcast(_ event: OrderBookEvent, assetID: String) {
        guard var feed = feeds[assetID] else { return }
        if case .connectionState = event { feed.connection = event }
        feeds[assetID] = feed
        for continuation in feed.consumers.values { continuation.yield(event) }
    }

    /// Finishes every consumer's stream when upstream ends of its own accord.
    private func closeFeed(assetID: String) {
        guard let feed = feeds[assetID] else { return }
        for continuation in feed.consumers.values { continuation.finish() }
        feeds[assetID] = nil
    }
}

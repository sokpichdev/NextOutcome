//
//  MarketLiveViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import OrderbookDomain

/// Drives the live market section on a market detail screen: a live order book plus a
/// price-history chart whose time window the user can change.
///
/// `@MainActor` + `@Observable` so SwiftUI re-renders as the book and history update.
@MainActor
@Observable
public final class MarketLiveViewModel {
    /// Connection status shown alongside the live book.
    public enum Connection {
        /// Establishing the stream.
        case connecting
        /// Receiving live updates.
        case live
        /// The stream ended (no more updates).
        case offline
    }

    /// The latest order book, or `nil` before the first arrives.
    public private(set) var book: OrderBook?
    /// The price-history series for the chart.
    public private(set) var history: [PriceHistoryPoint] = []
    /// The current connection status.
    public private(set) var connection: Connection = .connecting
    /// The chart's selected time window. Changing it reloads the history.
    public var interval: PriceHistoryInterval = .oneDay {
        didSet { Task { await loadHistory() } }
    }

    /// The token this view model streams.
    private let assetID: String
    /// Use case that streams reconciled book states.
    private let observeBook: ObserveOrderBookUseCase
    /// Use case that fetches chart history.
    private let fetchHistory: FetchPriceHistoryUseCase
    /// The running subscription task; `nil` when stopped.
    private var streamTask: Task<Void, Never>?

    /// Creates the view model.
    /// - Parameters:
    ///   - assetID: The token to stream.
    ///   - observeBook: Use case supplying live book states.
    ///   - fetchHistory: Use case supplying chart history.
    public init(
        assetID: String,
        observeBook: ObserveOrderBookUseCase,
        fetchHistory: FetchPriceHistoryUseCase
    ) {
        self.assetID = assetID
        self.observeBook = observeBook
        self.fetchHistory = fetchHistory
    }

    /// Loads chart history then subscribes to live book updates. No-op if already running.
    public func start() {
        guard streamTask == nil else { return }
        connection = .connecting
        streamTask = Task { [weak self] in
            guard let self else { return }
            await self.loadHistory()
            for await book in self.observeBook.execute(assetID: self.assetID) {
                self.book = book
                self.connection = .live
            }
            self.connection = .offline
        }
    }

    /// Cancels the subscription. Call from the view's teardown.
    public func stop() {
        streamTask?.cancel()
        streamTask = nil
    }

    /// Reloads the chart history for the current `interval`, ignoring errors (the chart
    /// simply shows nothing rather than surfacing an error for this secondary content).
    private func loadHistory() async {
        history = (try? await fetchHistory.execute(assetID: assetID, interval: interval)) ?? []
    }
}

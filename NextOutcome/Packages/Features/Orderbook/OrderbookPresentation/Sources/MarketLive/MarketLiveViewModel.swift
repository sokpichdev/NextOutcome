//
//  MarketLiveViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import OrderbookDomain

@MainActor
@Observable
public final class MarketLiveViewModel {
    public enum Connection {
        case connecting, live, offline
    }

    public private(set) var book: OrderBook?
    public private(set) var history: [PriceHistoryPoint] = []
    public private(set) var connection: Connection = .connecting
    public var interval: PriceHistoryInterval = .oneDay {
        didSet { Task { await loadHistory() } }
    }

    private let assetID: String
    private let observeBook: ObserveOrderBookUseCase
    private let fetchHistory: FetchPriceHistoryUseCase
    private var streamTask: Task<Void, Never>?

    public init(
        assetID: String,
        observeBook: ObserveOrderBookUseCase,
        fetchHistory: FetchPriceHistoryUseCase
    ) {
        self.assetID = assetID
        self.observeBook = observeBook
        self.fetchHistory = fetchHistory
    }

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

    public func stop() {
        streamTask?.cancel()
        streamTask = nil
    }

    private func loadHistory() async {
        history = (try? await fetchHistory.execute(assetID: assetID, interval: interval)) ?? []
    }
}

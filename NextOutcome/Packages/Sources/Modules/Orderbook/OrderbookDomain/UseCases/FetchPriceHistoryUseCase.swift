//
//  FetchPriceHistoryUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

/// Loads the price-history series for a market's chart. A thin use case that delegates to
/// the repository; it exists so the presentation layer depends on an intention, not a
/// concrete data source.
public struct FetchPriceHistoryUseCase: Sendable {
    /// The data source that actually fetches the history.
    private let repository: OrderbookRepository

    /// Creates the use case.
    /// - Parameter repository: The order book repository to fetch from.
    public init(repository: OrderbookRepository) {
        self.repository = repository
    }

    /// Fetches the price history for one token over a time window.
    /// - Parameters:
    ///   - assetID: The token whose history to fetch.
    ///   - interval: The time window. Defaults to one day.
    /// - Returns: The price-history points, oldest first.
    /// - Throws: A networking error if the fetch fails.
    public func execute(
        assetID: String,
        interval: PriceHistoryInterval = .oneDay
    ) async throws -> [PriceHistoryPoint] {
        try await repository.priceHistory(assetID: assetID, interval: interval)
    }
}

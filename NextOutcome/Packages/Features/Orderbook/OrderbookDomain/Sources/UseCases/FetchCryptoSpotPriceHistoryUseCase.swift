//
//  FetchCryptoSpotPriceHistoryUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 11/07/2026.
//

import Foundation

/// Loads the real dollar spot-price series for a crypto market's chart (the "Price" and
/// "Candles" chart modes). A thin use case that delegates to the repository.
public struct FetchCryptoSpotPriceHistoryUseCase: Sendable {
    /// The data source that actually fetches the series.
    private let repository: CryptoSpotPriceRepository

    /// Creates the use case.
    /// - Parameter repository: The crypto spot-price repository to fetch from.
    public init(repository: CryptoSpotPriceRepository) {
        self.repository = repository
    }

    /// Fetches the spot-price series for one asset over a fixed window.
    /// - Parameters:
    ///   - symbol: The asset symbol, e.g. `"BTC"`.
    ///   - eventStart: The window's open time.
    ///   - eventEnd: The window's close time.
    /// - Returns: The spot-price points, oldest first.
    /// - Throws: A networking error if the fetch fails.
    public func execute(symbol: String, eventStart: Date, eventEnd: Date) async throws -> [CryptoSpotPricePoint] {
        try await repository.spotPriceHistory(symbol: symbol, eventStart: eventStart, eventEnd: eventEnd)
    }
}

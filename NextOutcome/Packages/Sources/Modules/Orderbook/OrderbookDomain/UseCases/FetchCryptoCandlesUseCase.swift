//
//  FetchCryptoCandlesUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/08/2026.
//

import Foundation

/// Loads one page of real OHLC candle history for the "Candles" chart mode. A thin use
/// case that delegates to the repository.
///
/// Unlike the window-scoped spot-price series, the candle feed serves hours of past
/// candles and pages backwards via the `before` cursor, which is what makes the chart's
/// horizontal history scroll possible.
public struct FetchCryptoCandlesUseCase: Sendable {
    /// How many candles the feed serves per page (the server requires exactly this).
    public static let pageSize = 30

    /// The data source that actually fetches the candles.
    private let repository: CryptoSpotPriceRepository

    /// Creates the use case.
    /// - Parameter repository: The crypto spot-price repository to fetch from.
    public init(repository: CryptoSpotPriceRepository) {
        self.repository = repository
    }

    /// Fetches one page of candles, oldest first.
    /// - Parameters:
    ///   - symbol: The asset symbol, e.g. `"BTC"`.
    ///   - interval: The fixed candle width.
    ///   - before: Exclusive upper bound for paging back; `nil` for the newest page.
    /// - Returns: Up to `pageSize` candles, oldest first.
    /// - Throws: A networking error if the fetch fails.
    public func execute(symbol: String, interval: CandleInterval, before: Date? = nil) async throws -> [Candle] {
        try await repository.candles(symbol: symbol, interval: interval, before: before)
    }
}

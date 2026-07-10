//
//  FetchCryptoPriceWindowUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 11/07/2026.
//

import Foundation

/// Loads the dollar-denominated "price to beat" for a crypto market's fixed window. A
/// thin use case that delegates to the repository.
public struct FetchCryptoPriceWindowUseCase: Sendable {
    /// The data source that actually fetches the window snapshot.
    private let repository: CryptoSpotPriceRepository

    /// Creates the use case.
    /// - Parameter repository: The crypto spot-price repository to fetch from.
    public init(repository: CryptoSpotPriceRepository) {
        self.repository = repository
    }

    /// Fetches the open/close price snapshot for one asset's window.
    /// - Parameters:
    ///   - symbol: The asset symbol, e.g. `"BTC"`.
    ///   - eventStart: The window's open time.
    ///   - eventEnd: The window's close time.
    /// - Returns: The window's price snapshot.
    /// - Throws: A networking error if the fetch fails.
    public func execute(symbol: String, eventStart: Date, eventEnd: Date) async throws -> CryptoPriceWindow {
        try await repository.priceWindow(symbol: symbol, eventStart: eventStart, eventEnd: eventEnd)
    }
}

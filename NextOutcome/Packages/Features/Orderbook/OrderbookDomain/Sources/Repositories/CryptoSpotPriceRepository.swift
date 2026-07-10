//
//  CryptoSpotPriceRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 11/07/2026.
//

import Foundation

/// REST reads for a crypto asset's real spot price (in US dollars), scoped to a fixed
/// time window (e.g. a BTC Up/Down 5-minute round). Distinct from `OrderbookRepository`,
/// which only ever sees 0…1 contract-probability prices.
public protocol CryptoSpotPriceRepository: Sendable {
    /// The spot-price series within `[eventStart, eventEnd]`, oldest first.
    /// - Parameters:
    ///   - symbol: The asset symbol, e.g. `"BTC"`.
    ///   - eventStart: The window's open time.
    ///   - eventEnd: The window's close time.
    func spotPriceHistory(symbol: String, eventStart: Date, eventEnd: Date) async throws -> [CryptoSpotPricePoint]

    /// The window's open/close price snapshot (the "price to beat").
    /// - Parameters:
    ///   - symbol: The asset symbol, e.g. `"BTC"`.
    ///   - eventStart: The window's open time.
    ///   - eventEnd: The window's close time.
    func priceWindow(symbol: String, eventStart: Date, eventEnd: Date) async throws -> CryptoPriceWindow
}

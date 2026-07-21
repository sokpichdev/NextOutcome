//
//  CryptoSpotPriceStreaming.swift
//  NextOutcome
//
//  Created by Sok Pich on 13/07/2026.
//

import Foundation

/// Realtime port: a reconnecting stream of real dollar spot-price samples for one crypto
/// asset (BTC, ETH, SOL, …). The concrete socket (Polymarket's RTDS feed) lives in the
/// Data layer; Domain only sees this protocol.
///
/// Distinct from `MarketStreaming`, which streams 0…1 contract-probability book events —
/// this streams actual USD prices, the live source for the BTC screen's "Current Price".
public protocol CryptoSpotPriceStreaming: Sendable {
    /// Opens a reconnecting stream of dollar spot-price samples for one asset symbol.
    /// - Parameter symbol: The asset symbol, e.g. `"BTC"` (not the exchange pair).
    /// - Returns: An async stream of `CryptoSpotPricePoint`s as they arrive.
    func prices(symbol: String) -> AsyncStream<CryptoSpotPricePoint>
}

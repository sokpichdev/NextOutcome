//
//  CryptoSpotPrice.swift
//  NextOutcome
//
//  Created by Sok Pich on 11/07/2026.
//

import Foundation

/// A single BTC/ETH spot-price sample in real US dollars — distinct from
/// `PriceHistoryPoint`, which is a 0…1 contract-probability sample. Used to drive the
/// "Price" and "Candles" chart modes on the BTC live screen.
public struct CryptoSpotPricePoint: Hashable, Sendable {
    /// When this price was recorded.
    public let date: Date
    /// The spot price in US dollars at that time.
    public let price: Decimal

    /// Creates a spot-price point.
    /// - Parameters:
    ///   - date: The timestamp.
    ///   - price: The spot price in US dollars at that timestamp.
    public init(date: Date, price: Decimal) {
        self.date = date
        self.price = price
    }
}

/// The open/close prices for a crypto market's fixed time window (e.g. a BTC Up/Down
/// 5-minute round), used for the dollar-denominated "Price to beat".
public struct CryptoPriceWindow: Hashable, Sendable {
    /// The spot price at the window's open — the "price to beat". `nil` before the
    /// window has actually opened (or if the requested bounds don't align with a real
    /// window), not just when it hasn't closed yet.
    public let openPrice: Decimal?
    /// The spot price at the window's close, `nil` until the window completes.
    public let closePrice: Decimal?
    /// When this snapshot was computed.
    public let timestamp: Date
    /// Whether the window has finished (its `closePrice` is final).
    public let completed: Bool

    /// Creates a price-window snapshot.
    public init(openPrice: Decimal?, closePrice: Decimal?, timestamp: Date, completed: Bool) {
        self.openPrice = openPrice
        self.closePrice = closePrice
        self.timestamp = timestamp
        self.completed = completed
    }
}

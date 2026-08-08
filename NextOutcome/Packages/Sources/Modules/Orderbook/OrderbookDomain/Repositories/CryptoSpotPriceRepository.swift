//
//  CryptoSpotPriceRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 11/07/2026.
//

import Foundation

/// The fixed candle width served by the OHLC candle feed. Matches the recurring
/// window sizes Polymarket runs Up/Down markets on ("5m"/"15m" on the wire).
public enum CandleInterval: Sendable, Equatable {
    /// Five-minute candles (the BTC Up/Down 5m chart).
    case fiveMinute
    /// Fifteen-minute candles.
    case fifteenMinute

    /// The candle width in seconds.
    public var seconds: TimeInterval {
        switch self {
        case .fiveMinute: return 300
        case .fifteenMinute: return 900
        }
    }
}

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

    /// One page of real OHLC candle history, oldest first.
    ///
    /// This is the feed behind the web's candlestick chart — unlike `spotPriceHistory`,
    /// it is **not** scoped to a single betting window, so it can supply hours of past
    /// candles and page arbitrarily far back.
    /// - Parameters:
    ///   - symbol: The asset symbol, e.g. `"BTC"`.
    ///   - interval: The fixed candle width.
    ///   - before: Exclusive upper bound: only candles from buckets strictly before this
    ///     instant. `nil` asks for the newest page (which ends in the forming candle).
    func candles(symbol: String, interval: CandleInterval, before: Date?) async throws -> [Candle]
}

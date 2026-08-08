//
//  CryptoPriceDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 11/07/2026.
//

import Foundation

// MARK: - REST (polymarket.com/api/crypto/*)

/// One `GET /api/crypto/price-history` sample: `{ "timestamp": <ms>, "value": <USD> }`.
struct CryptoSpotPricePointDTO: Decodable {
    /// Unix timestamp in milliseconds.
    let timestamp: Double
    /// The spot price in US dollars at that time.
    let value: Double
}

/// `GET /api/chainlink-candles` → one page of real OHLC candles (the feed behind the
/// web's candlestick chart): `{ "candles": [{ "time": <sec>, "open": …, "high": …,
/// "low": …, "close": … }] }`.
struct ChainlinkCandlesResponseDTO: Decodable {
    /// The page of candles as sent by the server (order not guaranteed).
    let candles: [ChainlinkCandleDTO]
}

/// One `GET /api/chainlink-candles` candle. `time` is the bucket's start in Unix
/// **seconds** (unlike `/api/crypto/price-history`, which uses milliseconds).
struct ChainlinkCandleDTO: Decodable {
    /// The bucket's start, in Unix seconds.
    let time: Double
    /// The first price in the bucket, in US dollars.
    let open: Double
    /// The highest price in the bucket, in US dollars.
    let high: Double
    /// The lowest price in the bucket, in US dollars.
    let low: Double
    /// The last price in the bucket, in US dollars.
    let close: Double
}

/// `GET /api/crypto/crypto-price` → the window's open/close price snapshot.
/// `openPrice` is `null` in practice (e.g. before the window has opened, or when the
/// requested `eventStart`/`eventEnd` don't align with an actual completed window) — it's
/// not just `closePrice` that can be missing.
struct CryptoPriceWindowDTO: Decodable {
    /// The spot price at the window's open (the "price to beat"), when known.
    let openPrice: Double?
    /// The spot price at the window's close, `nil` until the window completes.
    let closePrice: Double?
    /// Unix timestamp in milliseconds this snapshot was computed.
    let timestamp: Double
    /// Whether the window has finished.
    let completed: Bool
}

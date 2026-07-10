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

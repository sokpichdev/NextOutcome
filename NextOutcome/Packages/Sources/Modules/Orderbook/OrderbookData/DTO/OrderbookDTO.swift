//
//  OrderbookDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

// MARK: - REST (/book, /prices-history)

/// One REST book level. Price and size arrive as strings (Polymarket sends numbers as
/// strings to preserve precision) and are parsed to `Decimal` by the mapper.
struct ClobLevelDTO: Decodable {
    /// The level's price, as a decimal string.
    let price: String
    /// The resting size, as a decimal string.
    let size: String
}

/// CLOB `GET /book` (keys arrive snake_case → converted). All fields optional to tolerate
/// partial responses.
struct ClobBookDTO: Decodable {
    /// The token this book is for, if the API echoes it back.
    let assetId: String?
    /// Buy levels.
    let bids: [ClobLevelDTO]?
    /// Sell levels.
    let asks: [ClobLevelDTO]?
    /// The market's tick size, as a decimal string.
    let tickSize: String?
    /// The last traded price, as a decimal string.
    let lastTradePrice: String?
}

/// CLOB `GET /prices-history` → `{ "history": [{ "t": 1699999999, "p": 0.62 }] }`.
struct PriceHistoryDTO: Decodable {
    /// One `(time, price)` sample.
    struct Point: Decodable {
        /// Unix timestamp in seconds.
        let t: Double
        /// Price at that time (0…1).
        let p: Double
    }
    /// The ordered list of samples.
    let history: [Point]
}

/// data `GET /trades` → array of executed trades. All fields optional to tolerate
/// missing data.
struct TradeDTO: Decodable {
    /// The trader's proxy wallet address.
    let proxyWallet: String?
    /// "BUY" or "SELL".
    let side: String?
    /// The trade size.
    let size: Double?
    /// The executed price (0…1).
    let price: Double?
    /// Unix timestamp in seconds.
    let timestamp: Double?
    /// The outcome name traded.
    let outcome: String?
    /// The on-chain transaction hash (used as a stable ID when present).
    let transactionHash: String?
}

// MARK: - WebSocket (market channel)

/// One WebSocket book level (same string-encoded shape as the REST level).
struct WSLevelDTO: Decodable {
    /// The level's price, as a decimal string.
    let price: String
    /// The resting size, as a decimal string.
    let size: String
}

/// One WebSocket incremental change to a single level.
struct WSChangeDTO: Decodable {
    /// The price level, as a decimal string.
    let price: String
    /// The new size at that level, as a decimal string (`"0"` removes it).
    let size: String
    /// Which side changed: "BUY" (bid) or "SELL" (ask).
    let side: String   // "BUY" | "SELL"
}

/// One market-channel message. All fields optional — shape varies by `eventType`.
struct MarketMessageDTO: Decodable {
    /// The message kind: "book", "price_change", "tick_size_change", "last_trade_price".
    let eventType: String?
    /// The token the message is about.
    let assetId: String?
    /// Full bid side (for a "book" snapshot).
    let bids: [WSLevelDTO]?
    /// Full ask side (for a "book" snapshot).
    let asks: [WSLevelDTO]?
    /// The current tick size.
    let tickSize: String?
    /// The updated tick size (for "tick_size_change").
    let newTickSize: String?
    /// A batch of level changes (for "price_change").
    let changes: [WSChangeDTO]?
    /// A single-change price, when the message carries just one change.
    let price: String?
    /// A single-change size.
    let size: String?
    /// A single-change side.
    let side: String?
}

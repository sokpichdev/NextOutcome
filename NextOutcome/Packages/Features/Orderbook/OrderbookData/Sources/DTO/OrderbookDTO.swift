//
//  OrderbookDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

// MARK: - REST (/book, /prices-history)

struct ClobLevelDTO: Decodable {
    let price: String
    let size: String
}

/// CLOB `GET /book` (keys arrive snake_case → converted).
struct ClobBookDTO: Decodable {
    let assetId: String?
    let bids: [ClobLevelDTO]?
    let asks: [ClobLevelDTO]?
    let tickSize: String?
    let lastTradePrice: String?
}

/// CLOB `GET /prices-history` → `{ "history": [{ "t": 1699999999, "p": 0.62 }] }`.
struct PriceHistoryDTO: Decodable {
    struct Point: Decodable {
        let t: Double
        let p: Double
    }
    let history: [Point]
}

// MARK: - WebSocket (market channel)

struct WSLevelDTO: Decodable {
    let price: String
    let size: String
}

struct WSChangeDTO: Decodable {
    let price: String
    let size: String
    let side: String   // "BUY" | "SELL"
}

/// One market-channel message. All fields optional — shape varies by `eventType`.
struct MarketMessageDTO: Decodable {
    let eventType: String?
    let assetId: String?
    let bids: [WSLevelDTO]?
    let asks: [WSLevelDTO]?
    let tickSize: String?
    let newTickSize: String?
    let changes: [WSChangeDTO]?
    let price: String?
    let size: String?
    let side: String?
}

//
//  RTDSCryptoPriceMapper.swift
//  NextOutcome
//
//  Created by Sok Pich on 13/07/2026.
//

import Foundation
import OrderbookDomain

/// A message from Polymarket's RTDS feed (`wss://ws-live-data.polymarket.com`).
/// The envelope is `{ topic, type, timestamp, payload, connection_id }`; only `topic`,
/// `type`, and `payload` matter here. `payload` is optional so connection acks / status
/// frames (which carry none) decode cleanly to "no point".
struct RTDSMessageDTO<Payload: Decodable>: Decodable {
    let topic: String
    let type: String
    let payload: Payload?
}

/// The `crypto_prices` / `crypto_prices_chainlink` `update` payload:
/// `{ symbol, timestamp(ms), value }`.
struct RTDSCryptoPricePayloadDTO: Decodable {
    /// Exchange pair, e.g. `"BTCUSDT"`.
    let symbol: String
    /// Unix timestamp in milliseconds for the update.
    let timestamp: Double
    /// The spot price in US dollars at that time.
    let value: Double
}

/// Pure translation between RTDS crypto-price frames and the domain's `CryptoSpotPricePoint`,
/// plus the app-symbol → exchange-pair mapping. Kept separate from `RTDSSocket` so the
/// decode/mapping is unit-testable without any live connection.
enum RTDSCryptoPriceMapper {
    /// The Chainlink-oracle crypto price topic (matches web's dollar price source).
    static let chainlinkTopic = "crypto_prices_chainlink"

    /// Maps a plain asset symbol the app carries (`"BTC"`, `"ETH"`, …) to the pair the
    /// chainlink topic keys on — a lowercase `"<coin>/usd"` (e.g. `"btc/usd"`), as observed
    /// on the live RTDS feed. Idempotent if the value is already a pair.
    /// - Parameter symbol: The app's asset symbol.
    /// - Returns: The RTDS chainlink pair symbol.
    static func exchangeSymbol(for symbol: String) -> String {
        let lower = symbol.lowercased()
        return lower.contains("/") ? lower : lower + "/usd"
    }

    /// Builds the RTDS subscription frame for the chainlink crypto-price stream. The
    /// `action: "subscribe"` field is mandatory — without it the server accepts the socket
    /// but silently streams nothing (verified against the live server).
    ///
    /// It deliberately subscribes to **all** symbols rather than server-filtering: the
    /// chainlink topic's server-side symbol filter was found unreliable against the live
    /// feed (a filtered subscription streamed nothing), so we take every symbol and match
    /// the one we want client-side in `point(from:exchangeSymbol:)`. The connect-time dump
    /// includes the current value for each symbol, so the chart populates immediately.
    /// - Returns: The encoded subscription frame to send on connect.
    static func subscribeMessage() -> Data {
        let payload: [String: Any] = [
            "action": "subscribe",
            "subscriptions": [[
                "topic": chainlinkTopic,
                "type": "update",
            ]],
        ]
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }

    /// Decodes one raw RTDS frame into a spot-price point, keeping only frames whose payload
    /// matches `exchangeSymbol`. Malformed or non-price frames map to `nil`.
    /// - Parameters:
    ///   - data: The raw frame bytes.
    ///   - exchangeSymbol: The exchange pair to keep (e.g. `"BTCUSDT"`).
    /// - Returns: The decoded point, or `nil` if the frame isn't a matching price update.
    static func point(from data: Data, exchangeSymbol: String) -> CryptoSpotPricePoint? {
        guard
            let message = try? JSONDecoder().decode(RTDSMessageDTO<RTDSCryptoPricePayloadDTO>.self, from: data),
            let payload = message.payload,
            payload.symbol == exchangeSymbol
        else { return nil }
        return CryptoSpotPricePoint(
            date: Date(timeIntervalSince1970: payload.timestamp / 1000),
            price: Decimal(payload.value)
        )
    }
}

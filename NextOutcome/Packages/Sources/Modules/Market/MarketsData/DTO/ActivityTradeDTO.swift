//
//  ActivityTradeDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import Foundation

/// Data API `/trades?market=<conditionId>&limit=50` row: one filled trade against an
/// outcome token. `timestamp` is Unix seconds as a JSON number; `size`/`price` are
/// numbers on this endpoint (unlike Gamma's stringified fields elsewhere), but decoded
/// tolerantly in case of a numeric-string variant.
struct ActivityTradeDTO: Decodable {
    /// The trader's proxy wallet address.
    let proxyWallet: String?
    /// "BUY" or "SELL".
    let side: String?
    /// Shares traded.
    let size: Decimal
    /// Price per share (0…1).
    let price: Decimal
    /// Unix timestamp in seconds.
    let timestamp: Double
    /// The outcome traded.
    let outcome: String?
    /// The trader's display name, if any.
    let name: String?
    /// A generated pseudonym, used when `name` is absent.
    let pseudonym: String?
    /// The trader's avatar URL string.
    let profileImage: String?
    /// The on-chain transaction hash (used as a stable id).
    let transactionHash: String?

    /// JSON keys for `ActivityTradeDTO`.
    enum CodingKeys: String, CodingKey {
        case proxyWallet, side, size, price, timestamp, outcome
        case name, pseudonym, profileImage, transactionHash
    }

    /// Tolerant decoder handling number-or-string amounts and timestamps.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        proxyWallet = try? c.decode(String.self, forKey: .proxyWallet)
        side = try? c.decode(String.self, forKey: .side)
        size = DTODecoding.decimal(c, .size)
        price = DTODecoding.decimal(c, .price)
        timestamp = Self.timestampValue(c)
        outcome = try? c.decode(String.self, forKey: .outcome)
        name = try? c.decode(String.self, forKey: .name)
        pseudonym = try? c.decode(String.self, forKey: .pseudonym)
        profileImage = try? c.decode(String.self, forKey: .profileImage)
        transactionHash = try? c.decode(String.self, forKey: .transactionHash)
    }

    /// Reads the timestamp accepting a JSON double, int, or numeric string; defaults to 0.
    private static func timestampValue(_ c: KeyedDecodingContainer<CodingKeys>) -> Double {
        if let d = try? c.decode(Double.self, forKey: .timestamp) { return d }
        if let i = try? c.decode(Int.self, forKey: .timestamp) { return Double(i) }
        if let s = try? c.decode(String.self, forKey: .timestamp), let d = Double(s) { return d }
        return 0
    }
}

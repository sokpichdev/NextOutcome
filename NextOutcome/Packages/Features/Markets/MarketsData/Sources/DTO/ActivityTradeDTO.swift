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
    let proxyWallet: String?
    let side: String?
    let size: Decimal
    let price: Decimal
    let timestamp: Double
    let outcome: String?
    let name: String?
    let pseudonym: String?
    let profileImage: String?
    let transactionHash: String?

    enum CodingKeys: String, CodingKey {
        case proxyWallet, side, size, price, timestamp, outcome
        case name, pseudonym, profileImage, transactionHash
    }

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

    private static func timestampValue(_ c: KeyedDecodingContainer<CodingKeys>) -> Double {
        if let d = try? c.decode(Double.self, forKey: .timestamp) { return d }
        if let i = try? c.decode(Int.self, forKey: .timestamp) { return Double(i) }
        if let s = try? c.decode(String.self, forKey: .timestamp), let d = Double(s) { return d }
        return 0
    }
}

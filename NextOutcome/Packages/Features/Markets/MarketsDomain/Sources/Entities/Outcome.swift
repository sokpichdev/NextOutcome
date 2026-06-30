//
//  Outcome.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//
import Foundation

public struct Outcome: Identifiable, Hashable {
    public let id: String // token Id - keep as String, never expose raw
    public let title: String // "yes" / "no"
    public let price: Decimal // 0…1 midpoint (fall back to last-trade if spread > 0.10)
    public let isWinner: Bool?
    
    public init(id: String, title: String, price: Decimal, isWinner: Bool? = nil) {
        self.id = id
        self.title = title
        self.price = price
        self.isWinner = isWinner
    }
    
    /// complement price for binary markets: No = 1 - Yes
    public var complement: Decimal { 1 - price }
}

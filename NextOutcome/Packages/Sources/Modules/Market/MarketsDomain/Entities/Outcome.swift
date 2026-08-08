//
//  Outcome.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//
import Foundation

/// One tradeable choice within a `Market` (e.g. "Yes", "No", or a team).
public struct Outcome: Identifiable, Hashable {
    /// The CLOB token id (kept as a `String`; the raw numeric form is never exposed).
    public let id: String // token Id - keep as String, never expose raw
    /// The outcome label, e.g. "Yes" / "No".
    public let title: String // "yes" / "no"
    /// The current price as a probability (0…1) — the midpoint, falling back to the last
    /// trade when the spread is wide.
    public let price: Decimal // 0…1 midpoint (fall back to last-trade if spread > 0.10)
    /// Whether this outcome won, once the market resolves (`nil` while unresolved).
    public let isWinner: Bool?

    /// Creates an outcome.
    /// - Parameters:
    ///   - id: The token id.
    ///   - title: The outcome label.
    ///   - price: The price (0…1).
    ///   - isWinner: Whether it won, if resolved.
    public init(id: String, title: String, price: Decimal, isWinner: Bool? = nil) {
        self.id = id
        self.title = title
        self.price = price
        self.isWinner = isWinner
    }

    /// complement price for binary markets: No = 1 - Yes
    public var complement: Decimal { 1 - price }
}

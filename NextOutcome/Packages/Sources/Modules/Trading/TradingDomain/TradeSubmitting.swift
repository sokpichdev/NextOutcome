//
//  TradeSubmitting.swift
//  NextOutcome
//

import Foundation

/// The two sides a mock trade can take. Mirrors `MarketsPresentation.Side` (kept
/// separate there to avoid that presentation package depending on this domain).
public enum TradeSide: String, Sendable, Hashable {
    /// Betting the outcome will happen.
    case yes
    /// Betting the outcome will not happen.
    case no
}

/// Result of a submitted trade. `simulated` is always `true` until Task D swaps in
/// the real submitter behind this same protocol.
public struct TradeReceipt: Sendable {
    /// `true` when the receipt came from the mock submitter rather than a real fill.
    public let simulated: Bool
    /// How many shares the trade bought.
    public let shares: Decimal

    /// Creates a trade receipt.
    /// - Parameters:
    ///   - simulated: Whether this was a simulated trade.
    ///   - shares: The number of shares acquired.
    public init(simulated: Bool, shares: Decimal) {
        self.simulated = simulated
        self.shares = shares
    }
}

/// The trade sheet's only dependency on "sending an order." `SimulatedTradeSubmitter`
/// implements this today; Task D swaps in a real implementation with zero UI changes.
public protocol TradeSubmitting: Sendable {
    /// Submits a trade and returns a receipt once it's accepted.
    /// - Parameters:
    ///   - marketID: The market to trade in.
    ///   - side: Yes or No.
    ///   - amountUSD: The dollar amount to spend.
    ///   - priceCents: The price per share in cents.
    /// - Returns: A `TradeReceipt` describing the result.
    /// - Throws: An error if the trade is rejected or fails.
    func submit(marketID: String, side: TradeSide, amountUSD: Decimal, priceCents: Decimal) async throws -> TradeReceipt
}

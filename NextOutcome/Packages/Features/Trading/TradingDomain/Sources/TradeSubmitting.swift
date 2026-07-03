//
//  TradeSubmitting.swift
//  NextOutcome
//

import Foundation

/// The two sides a mock trade can take. Mirrors `MarketsPresentation.Side` (kept
/// separate there to avoid that presentation package depending on this domain).
public enum TradeSide: String, Sendable, Hashable {
    case yes
    case no
}

/// Result of a submitted trade. `simulated` is always `true` until Task D swaps in
/// the real submitter behind this same protocol.
public struct TradeReceipt: Sendable {
    public let simulated: Bool
    public let shares: Decimal

    public init(simulated: Bool, shares: Decimal) {
        self.simulated = simulated
        self.shares = shares
    }
}

/// The trade sheet's only dependency on "sending an order." `SimulatedTradeSubmitter`
/// implements this today; Task D swaps in a real implementation with zero UI changes.
public protocol TradeSubmitting: Sendable {
    func submit(marketID: String, side: TradeSide, amountUSD: Decimal, priceCents: Decimal) async throws -> TradeReceipt
}

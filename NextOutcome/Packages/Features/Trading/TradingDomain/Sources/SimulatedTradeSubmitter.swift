//
//  SimulatedTradeSubmitter.swift
//  NextOutcome
//

import Foundation

/// Sends no order and persists nothing. Waits ~300ms (to feel like a real round-trip)
/// then returns a simulated receipt computed via `PayoutCalculator`. This is the only
/// `TradeSubmitting` implementation until Task D wires up the real proxy/CLOB flow.
public struct SimulatedTradeSubmitter: TradeSubmitting {
    public init() {}

    public func submit(marketID: String, side: TradeSide, amountUSD: Decimal, priceCents: Decimal) async throws -> TradeReceipt {
        try await Task.sleep(nanoseconds: 300_000_000)
        let (shares, _) = PayoutCalculator.potential(amountUSD: amountUSD, priceCents: priceCents)
        return TradeReceipt(simulated: true, shares: shares)
    }
}

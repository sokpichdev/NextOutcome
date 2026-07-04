//
//  SimulatedTradeSubmitter.swift
//  NextOutcome
//

import Foundation

/// Sends no order and persists nothing. Waits ~300ms (to feel like a real round-trip)
/// then returns a simulated receipt computed via `PayoutCalculator`. This is the only
/// `TradeSubmitting` implementation until Task D wires up the real proxy/CLOB flow.
public struct SimulatedTradeSubmitter: TradeSubmitting {
    /// Creates the simulated submitter. Takes no dependencies because it talks to nothing.
    public init() {}

    /// Pretends to submit a trade: waits briefly, then returns a fake receipt.
    ///
    /// The short sleep makes the UI's loading spinner feel like a genuine network
    /// round-trip. No order is sent and nothing is stored.
    /// - Parameters:
    ///   - marketID: The market being traded (ignored by the simulation).
    ///   - side: Yes or No (ignored by the simulation).
    ///   - amountUSD: The dollar amount the user wants to spend.
    ///   - priceCents: The price per share in cents.
    /// - Returns: A simulated `TradeReceipt` with the shares the amount would buy.
    public func submit(marketID: String, side: TradeSide, amountUSD: Decimal, priceCents: Decimal) async throws -> TradeReceipt {
        try await Task.sleep(nanoseconds: 300_000_000)
        let (shares, _) = PayoutCalculator.potential(amountUSD: amountUSD, priceCents: priceCents)
        return TradeReceipt(simulated: true, shares: shares)
    }
}

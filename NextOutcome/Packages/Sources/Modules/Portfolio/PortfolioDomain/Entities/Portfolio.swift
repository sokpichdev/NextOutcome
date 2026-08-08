//
//  Portfolio.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Aggregate snapshot for a watched wallet: total value + open positions.
public struct Portfolio: Hashable, Sendable {
    /// The wallet address this snapshot belongs to.
    public let address: String
    /// The total portfolio value in dollars.
    public let value: Decimal
    /// The open positions making up the portfolio.
    public let positions: [Position]

    /// Creates a portfolio snapshot.
    /// - Parameters:
    ///   - address: The wallet address.
    ///   - value: Total value in dollars.
    ///   - positions: The open positions.
    public init(address: String, value: Decimal, positions: [Position]) {
        self.address = address
        self.value = value
        self.positions = positions
    }

    /// Sum of pre-computed cash PnL across open positions.
    public var totalCashPnl: Decimal {
        positions.reduce(0) { $0 + $1.cashPnl }
    }

    /// Cost basis implied by current value minus PnL; used for an overall percent.
    public var totalPercentPnl: Decimal {
        let basis = value - totalCashPnl
        guard basis > 0 else { return 0 }
        return (totalCashPnl / basis) * 100
    }

    /// Whether the portfolio holds no open positions.
    public var isEmpty: Bool { positions.isEmpty }
}

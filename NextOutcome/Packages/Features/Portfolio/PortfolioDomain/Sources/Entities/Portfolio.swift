//
//  Portfolio.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Aggregate snapshot for a watched wallet: total value + open positions.
public struct Portfolio: Hashable, Sendable {
    public let address: String
    public let value: Decimal
    public let positions: [Position]

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

    public var isEmpty: Bool { positions.isEmpty }
}

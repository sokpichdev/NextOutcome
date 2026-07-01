//
//  PriceHistoryPoint.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

public struct PriceHistoryPoint: Hashable, Sendable {
    public let date: Date
    public let price: Decimal   // 0…1

    public init(date: Date, price: Decimal) {
        self.date = date
        self.price = price
    }
}

/// Time window for the price-history chart (maps to CLOB `interval`).
public enum PriceHistoryInterval: String, Sendable, CaseIterable {
    case oneHour = "1h"
    case sixHour = "6h"
    case oneDay = "1d"
    case oneWeek = "1w"
    case oneMonth = "1m"
    case max = "max"
}

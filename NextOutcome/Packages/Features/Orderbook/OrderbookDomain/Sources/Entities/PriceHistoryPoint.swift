//
//  PriceHistoryPoint.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// A single point on the price-history chart: a price at a moment in time.
public struct PriceHistoryPoint: Hashable, Sendable {
    /// When this price was recorded.
    public let date: Date
    /// The price at that time, as a probability (0…1).
    public let price: Decimal   // 0…1

    /// Creates a price-history point.
    /// - Parameters:
    ///   - date: The timestamp.
    ///   - price: The price (0…1) at that timestamp.
    public init(date: Date, price: Decimal) {
        self.date = date
        self.price = price
    }
}

/// Time window for the price-history chart (maps to CLOB `interval`).
public enum PriceHistoryInterval: String, Sendable, CaseIterable {
    /// Last hour.
    case oneHour = "1h"
    /// Last six hours.
    case sixHour = "6h"
    /// Last day.
    case oneDay = "1d"
    /// Last week.
    case oneWeek = "1w"
    /// Last month.
    case oneMonth = "1m"
    /// The full available history.
    case max = "max"
}

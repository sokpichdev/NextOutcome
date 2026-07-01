//
//  ClosedPosition.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// A settled/closed position. Slimmer than `Position` and carries realized PnL + a close time.
public struct ClosedPosition: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let slug: String
    public let outcome: String
    public let iconURL: URL?
    public let realizedPnl: Decimal
    public let percentRealizedPnl: Decimal
    public let timestamp: Date

    public init(
        id: String, title: String, slug: String, outcome: String, iconURL: URL?,
        realizedPnl: Decimal, percentRealizedPnl: Decimal, timestamp: Date
    ) {
        self.id = id
        self.title = title
        self.slug = slug
        self.outcome = outcome
        self.iconURL = iconURL
        self.realizedPnl = realizedPnl
        self.percentRealizedPnl = percentRealizedPnl
        self.timestamp = timestamp
    }

    public var isProfitable: Bool { realizedPnl >= 0 }
}

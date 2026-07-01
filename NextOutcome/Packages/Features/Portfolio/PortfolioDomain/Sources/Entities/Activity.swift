//
//  Activity.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

public enum ActivityKind: String, Sendable, Hashable {
    case buy, sell, split, merge, redeem, reward, conversion, other

    public var label: String {
        switch self {
        case .buy: return "Buy"
        case .sell: return "Sell"
        case .split: return "Split"
        case .merge: return "Merge"
        case .redeem: return "Redeem"
        case .reward: return "Reward"
        case .conversion: return "Convert"
        case .other: return "Activity"
        }
    }
}

/// One row in a watched wallet's activity feed (trades + lifecycle events).
public struct Activity: Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: ActivityKind
    public let title: String
    public let slug: String
    public let outcome: String
    public let iconURL: URL?
    public let size: Decimal          // shares
    public let usdcSize: Decimal      // USD notional
    public let price: Decimal         // 0…1
    public let timestamp: Date

    public init(
        id: String, kind: ActivityKind, title: String, slug: String, outcome: String,
        iconURL: URL?, size: Decimal, usdcSize: Decimal, price: Decimal, timestamp: Date
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.slug = slug
        self.outcome = outcome
        self.iconURL = iconURL
        self.size = size
        self.usdcSize = usdcSize
        self.price = price
        self.timestamp = timestamp
    }

    public var isCredit: Bool {
        kind == .sell || kind == .redeem || kind == .reward
    }
}

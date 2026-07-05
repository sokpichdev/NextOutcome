//
//  Activity.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// The type of a wallet activity row. Raw values match the Data API's activity types.
public enum ActivityKind: String, Sendable, Hashable {
    case buy, sell, split, merge, redeem, reward, conversion, other

    /// A short human-readable label for the row's badge.
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
    /// Stable identity for the activity row.
    public let id: String
    /// What kind of activity this is (buy, sell, redeem, …).
    public let kind: ActivityKind
    /// The market title.
    public let title: String
    /// The market's URL slug.
    public let slug: String
    /// The outcome involved.
    public let outcome: String
    /// The market's icon image, if any.
    public let iconURL: URL?
    /// Number of shares involved.
    public let size: Decimal          // shares
    /// The USD notional amount.
    public let usdcSize: Decimal      // USD notional
    /// The price per share (0…1).
    public let price: Decimal         // 0…1
    /// When the activity happened.
    public let timestamp: Date

    /// Creates an activity row.
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

    /// Whether this activity put money *into* the wallet (sell/redeem/reward), used to
    /// choose the amount's sign and colour.
    public var isCredit: Bool {
        kind == .sell || kind == .redeem || kind == .reward
    }
}

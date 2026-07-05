//
//  LeaderboardEntry.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// How the leaderboard is ranked.
public enum LeaderboardMetric: String, Sendable, CaseIterable {
    /// Ranked by trading volume.
    case volume
    /// Ranked by realized profit.
    case profit

    /// The human-readable label for the metric toggle.
    public var title: String {
        switch self {
        case .volume: return "Volume"
        case .profit: return "Profit"
        }
    }
}

/// Time window for the leaderboard.
public enum LeaderboardWindow: String, Sendable, CaseIterable {
    /// Last 24 hours.
    case day = "1d"
    /// Last 7 days.
    case week = "7d"
    /// Last 30 days.
    case month = "30d"
    /// All-time.
    case all = "all"

    /// The short label for the window toggle (e.g. "1W").
    public var title: String {
        switch self {
        case .day: return "1D"
        case .week: return "1W"
        case .month: return "1M"
        case .all: return "All"
        }
    }
}

/// One ranked trader.
public struct LeaderboardEntry: Identifiable, Hashable, Sendable {
    /// The trader's proxy wallet address (also this row's identity).
    public let id: String        // proxy wallet
    /// The trader's 1-based rank.
    public let rank: Int
    /// The trader's display name.
    public let name: String
    /// The trader's avatar image, if any.
    public let profileImageURL: URL?
    /// The ranking amount — volume or profit depending on the requested metric.
    public let amount: Decimal    // volume or profit, per the requested metric

    /// Creates a leaderboard entry.
    public init(id: String, rank: Int, name: String, profileImageURL: URL?, amount: Decimal) {
        self.id = id
        self.rank = rank
        self.name = name
        self.profileImageURL = profileImageURL
        self.amount = amount
    }
}

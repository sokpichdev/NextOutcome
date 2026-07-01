//
//  LeaderboardEntry.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// How the leaderboard is ranked.
public enum LeaderboardMetric: String, Sendable, CaseIterable {
    case volume
    case profit

    public var title: String {
        switch self {
        case .volume: return "Volume"
        case .profit: return "Profit"
        }
    }
}

/// Time window for the leaderboard.
public enum LeaderboardWindow: String, Sendable, CaseIterable {
    case day = "1d"
    case week = "7d"
    case month = "30d"
    case all = "all"

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
    public let id: String        // proxy wallet
    public let rank: Int
    public let name: String
    public let profileImageURL: URL?
    public let amount: Decimal    // volume or profit, per the requested metric

    public init(id: String, rank: Int, name: String, profileImageURL: URL?, amount: Decimal) {
        self.id = id
        self.rank = rank
        self.name = name
        self.profileImageURL = profileImageURL
        self.amount = amount
    }
}

//
//  Event.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

public struct Event: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let slug: String
    public let markets: [Market]
    public let volume: Decimal
    public let imageURL: URL?
    public let tags: [Tag]
    /// Kickoff time for sports events, from Gamma's `gameStartTime`. Absent for non-sports events.
    public let gameStartTime: Date?
    /// Event-level context/description shown in the "Market Context" rules tab. Absent for many events.
    public let description: String?

    public init(
        id: String,
        title: String,
        slug: String,
        markets: [Market],
        volume: Decimal,
        imageURL: URL?,
        tags: [Tag] = [],
        gameStartTime: Date? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.title = title
        self.slug = slug
        self.markets = markets
        self.volume = volume
        self.imageURL = imageURL
        self.tags = tags
        self.gameStartTime = gameStartTime
        self.description = description
    }

    /// True when at least one market carries a sports section hint (moneyline/spreads/totals/…),
    /// meaning the event has team-based outcomes rather than a plain Yes/No question.
    public var hasTeams: Bool { markets.contains { $0.sportsMarketType != nil } }

    /// True when every market has closed. False for an event with no markets.
    public var isResolved: Bool { !markets.isEmpty && markets.allSatisfy(\.isResolved) }
}

//
//  Event.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

/// A group of related markets shown together as one card/screen — for example a sports
/// game (with moneyline, spread, and totals markets) or a multi-outcome election.
public struct Event: Identifiable, Hashable {
    /// The event's unique id.
    public let id: String
    /// The event title.
    public let title: String
    /// The event's URL slug.
    public let slug: String
    /// The markets belonging to this event.
    public let markets: [Market]
    /// Total volume across the event's markets, in dollars.
    public let volume: Decimal
    /// The event's image, if any.
    public let imageURL: URL?
    /// The category tags applied to this event.
    public let tags: [Tag]
    /// Kickoff time for sports events, from Gamma's `gameStartTime`. Absent for non-sports events.
    public let gameStartTime: Date?
    /// Event-level context/description shown in the "Market Context" rules tab. Absent for many events.
    public let description: String?

    /// Creates an event. Usually built by the mapping layer from a DTO.
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

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
    /// The recurring-market series slug this event belongs to (e.g. `"btc-up-or-down-5m"`),
    /// from Gamma's `series[0].slug`. `nil` for non-recurring events. Raw passthrough —
    /// interpreting the cadence from the slug's suffix is a Presentation-layer concern (see
    /// `CryptoHubViewModel.Timeframe`), matching the existing `groupItemTitle`/
    /// `sportsMarketType` pattern of Domain carrying the raw signal unchanged.
    public let recurrence: String?
    /// Trailing-24-hour trading volume, from Gamma's `volume24hr`. `0` when absent.
    public let volume24hr: Decimal
    /// Available liquidity in dollars, from Gamma's `liquidity`. `0` when absent.
    public let liquidity: Decimal
    /// A 0-1 "competitiveness" score Gamma computes (closer to 1 = closer to 50/50 odds),
    /// from Gamma's `competitive`. `nil` when absent.
    public let competitive: Double?
    /// When the event was created, from Gamma's `creationDate`. `nil` when absent.
    public let creationDate: Date?

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
        description: String? = nil,
        recurrence: String? = nil,
        volume24hr: Decimal = 0,
        liquidity: Decimal = 0,
        competitive: Double? = nil,
        creationDate: Date? = nil
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
        self.recurrence = recurrence
        self.volume24hr = volume24hr
        self.liquidity = liquidity
        self.competitive = competitive
        self.creationDate = creationDate
    }

    /// True when at least one market carries a sports section hint (moneyline/spreads/totals/…),
    /// meaning the event has team-based outcomes rather than a plain Yes/No question.
    public var hasTeams: Bool { markets.contains { $0.sportsMarketType != nil } }

    /// True when every market has closed. False for an event with no markets.
    public var isResolved: Bool { !markets.isEmpty && markets.allSatisfy(\.isResolved) }
}

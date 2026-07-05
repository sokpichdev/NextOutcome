//
//  MarketRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SharedDomain

/// Read access to Polymarket's market/event catalogue and the social data around it
/// (holders, comments, trades). The concrete implementation lives in the Data layer; the
/// Domain and Presentation layers only ever see this protocol.
public protocol MarketRepository: Sendable {
    /// Fetches one page of events, optionally filtered by tag, sorted/scoped, and bounded
    /// to events that started within `period`.
    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event>
    /// All events of a Gamma series (e.g. a tournament). Bounded, unpaginated.
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event]
    /// Live/final scores for game events, keyed by event id. Missing ids are simply absent.
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult]
    /// Team reference data (name, logo, colour) for a sports league, e.g. "fifwc".
    func fetchTeams(league: String) async throws -> [GameTeam]
    /// Most-recently-finished events of a series (closed, newest first) — e.g. the last
    /// knockout round played.
    func fetchCompletedEvents(seriesID: String, limit: Int) async throws -> [Event]
    /// Fetches one page of individual markets.
    func fetchMarkets(cursor: String?) async throws -> Page<Market>
    /// Fetches the biggest 24h market movers for the Breaking feed, optionally scoped to a
    /// category tag, ranked by the magnitude of their 24h probability move.
    func movers(tagID: String?) async throws -> [Mover]
    /// Fetches a single event by its URL slug.
    func fetchEvent(slug: String) async throws -> Event
    /// Full-text searches markets by query string.
    func searchMarkets(query: String) async throws -> [Market]
    /// Full-text searches events by query string.
    func searchEvents(query: String) async throws -> [Event]
    /// Fetches the filter tags (categories) shown in the chip row.
    func fetchTags() async throws -> [Tag]
    /// Fetches the top holders of a market's condition.
    func holders(conditionId: String) async throws -> [Holder]
    /// Fetches the comments on an event's discussion thread, sorted and optionally
    /// restricted to commenters who hold a position in the market.
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment]
    /// Fetches recent trades for a market's condition.
    func trades(conditionId: String) async throws -> [ActivityTrade]
    /// Fetches a user's positions in an event — used for the comment "holder" badge.
    func commenterPositions(proxyWallet: String, eventID: String) async throws -> [CommentHolding]
}

public extension MarketRepository {
    /// Defaults so existing conformers (stubs, test fakes) need no change; the live Gamma
    /// repository overrides these.
    func fetchTeams(league: String) async throws -> [GameTeam] { [] }
    func fetchCompletedEvents(seriesID: String, limit: Int) async throws -> [Event] { [] }
    func searchEvents(query: String) async throws -> [Event] { [] }
    func commenterPositions(proxyWallet: String, eventID: String) async throws -> [CommentHolding] { [] }
    func movers(tagID: String?) async throws -> [Mover] { [] }
}

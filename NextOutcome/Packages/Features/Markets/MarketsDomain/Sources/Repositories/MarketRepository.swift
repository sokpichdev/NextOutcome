//
//  MarketRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SharedDomain

public protocol MarketRepository: Sendable {
    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus) async throws -> Page<Event>
    /// All events of a Gamma series (e.g. a tournament). Bounded, unpaginated.
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event]
    /// Live/final scores for game events, keyed by event id. Missing ids are simply absent.
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult]
    func fetchMarkets(cursor: String?) async throws -> Page<Market>
    func fetchEvent(slug: String) async throws -> Event
    func searchMarkets(query: String) async throws -> [Market]
    func fetchTags() async throws -> [Tag]
    func holders(conditionId: String) async throws -> [Holder]
    func comments(eventID: String) async throws -> [Comment]
    func trades(conditionId: String) async throws -> [ActivityTrade]
}

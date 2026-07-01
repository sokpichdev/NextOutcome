//
//  MarketRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SharedDomain

public protocol MarketRepository: Sendable {
    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus) async throws -> Page<Event>
    func fetchMarkets(cursor: String?) async throws -> Page<Market>
    func fetchEvent(slug: String) async throws -> Event
    func searchMarkets(query: String) async throws -> [Market]
    func fetchTags() async throws -> [Tag]
    func holders(conditionId: String) async throws -> [Holder]
}

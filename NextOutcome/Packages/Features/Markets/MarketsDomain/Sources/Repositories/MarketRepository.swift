//
//  MarketRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SharedDomain

public protocol MarketRepository: Sendable {
    func fetchMarkets(cursor: String?) async throws -> Page<Market>
    func fetchEvent(slug: String) async throws -> Event
    func searchMarkets(query: String) async throws -> [Market]
}

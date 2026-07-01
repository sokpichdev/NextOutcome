//
//  GammaMarketRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation
import Networking
import MarketsDomain
import SharedDomain

public struct GammaMarketRepository: MarketRepository {
    private let client: APIClient
    
    public init(client: APIClient) {
        self.client = client
    }
    
    public func fetchEvents(cursor: String?, tagID: String?) async throws -> Page<Event> {
        var query: [String: String] = ["limit": "20", "active": "true"]
        if let cursor { query["next_cursor"] = cursor }
        if let tagID { query["tag_id"] = tagID }

        let endpoint = Endpoint(host: .gamma, path: "/events", query: query)
        let envelope: EventsEnvelope = try await client.fetch(endpoint)
        let events = envelope.data.map(MarketMapper.event(from:))
        return Page(items: events, nextCursor: envelope.nextCursor)
    }
    
    public func fetchMarkets(cursor: String?) async throws -> Page<Market> {
        var query: [String: String] = ["limit": "20", "active": "true"]
        if let cursor { query["next_cursor"] = cursor }
        let endpoint = Endpoint(host: .gamma, path: "/events", query: query)
        let envelope: EventsEnvelope = try await client.fetch(endpoint)
        let markets = envelope.data.flatMap { $0.markets }.map(MarketMapper.market(from:))
        return Page(items: markets, nextCursor: envelope.nextCursor)
    }
    
    public func fetchEvent(slug: String) async throws -> Event {
        let endpoint = Endpoint(host: .gamma, path: "/events/slug/\(slug)")
        let dto: EventDTO = try await client.fetch(endpoint)
        return MarketMapper.event(from: dto)
    }
    
    public func searchMarkets(query: String) async throws -> [Market] {
            let endpoint = Endpoint(
                host: .gamma,
                path: "/public-search",
                query: ["term": query, "type": "markets"]
            )
            // Search returns a composite envelope — decode markets array only
            struct SearchEnvelope: Decodable { let markets: [MarketDTO] }
            let envelope: SearchEnvelope = try await client.fetch(endpoint)
            return envelope.markets.map(MarketMapper.market(from:))
        }

    public func fetchTags() async throws -> [Tag] {
        let endpoint = Endpoint(
            host: .gamma,
            path: "/tags",
            query: ["limit": "50", "is_carousel": "true"]
        )
        let dtos: [TagDTO] = try await client.fetch(endpoint)
        return dtos.map(MarketMapper.tag(from:))
    }
}

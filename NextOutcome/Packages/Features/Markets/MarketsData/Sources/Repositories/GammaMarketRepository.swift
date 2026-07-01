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
    
    private static let pageSize = 20

    /// Gamma `/events` returns a bare JSON array and paginates by `offset`
    /// (keyset cursors are rejected here), so we carry the offset in `Page.nextCursor`.
    private func eventsQuery(offset: Int, tagID: String?) -> [String: String] {
        var query: [String: String] = [
            "limit": "\(Self.pageSize)",
            "offset": "\(offset)",
            "active": "true",
            "closed": "false",
            "order": "volume24hr",
            "ascending": "false",
        ]
        if let tagID { query["tag_id"] = tagID }
        return query
    }

    public func fetchEvents(cursor: String?, tagID: String?) async throws -> Page<Event> {
        let offset = cursor.flatMap(Int.init) ?? 0
        let endpoint = Endpoint(host: .gamma, path: "/events", query: eventsQuery(offset: offset, tagID: tagID))
        let dtos: [EventDTO] = try await client.fetch(endpoint)
        let events = dtos.map(MarketMapper.event(from:))
        let nextCursor = dtos.count == Self.pageSize ? "\(offset + Self.pageSize)" : nil
        return Page(items: events, nextCursor: nextCursor)
    }

    public func fetchMarkets(cursor: String?) async throws -> Page<Market> {
        let offset = cursor.flatMap(Int.init) ?? 0
        let endpoint = Endpoint(host: .gamma, path: "/events", query: eventsQuery(offset: offset, tagID: nil))
        let dtos: [EventDTO] = try await client.fetch(endpoint)
        let markets = dtos.flatMap { $0.markets }.map(MarketMapper.market(from:))
        let nextCursor = dtos.count == Self.pageSize ? "\(offset + Self.pageSize)" : nil
        return Page(items: markets, nextCursor: nextCursor)
    }

    public func fetchEvent(slug: String) async throws -> Event {
        let endpoint = Endpoint(host: .gamma, path: "/events", query: ["slug": slug])
        let dtos: [EventDTO] = try await client.fetch(endpoint)
        guard let dto = dtos.first else { throw APIError.badURL }
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

    public func holders(conditionId: String) async throws -> [Holder] {
        let endpoint = Endpoint(
            host: .data,
            path: "/holders",
            query: ["market": conditionId, "limit": "20"]
        )
        let groups: [HolderGroupDTO] = try await client.fetch(endpoint)
        return MarketMapper.holders(from: groups)
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

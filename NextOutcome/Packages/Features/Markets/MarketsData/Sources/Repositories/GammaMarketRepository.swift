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

    public func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus) async throws -> Page<Event> {
        let offset = cursor.flatMap(Int.init) ?? 0
        let query = GammaEventQuery.params(offset: offset, tagID: tagID, sort: sort, status: status)
        let endpoint = Endpoint(host: .gamma, path: "/events", query: query)
        let dtos: [EventDTO] = try await client.fetch(endpoint)
        let events = dtos.map(MarketMapper.event(from:))
        let nextCursor = dtos.count == Self.pageSize ? "\(offset + Self.pageSize)" : nil
        return Page(items: events, nextCursor: nextCursor)
    }

    public func fetchMarkets(cursor: String?) async throws -> Page<Market> {
        let offset = cursor.flatMap(Int.init) ?? 0
        let endpoint = Endpoint(host: .gamma, path: "/events", query: GammaEventQuery.params(offset: offset, tagID: nil, sort: .volume24h, status: .active))
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

    public func comments(eventID: String) async throws -> [Comment] {
        let endpoint = Endpoint(
            host: .gamma,
            path: "/comments",
            query: ["parent_entity_type": "Event", "parent_entity_id": eventID]
        )
        let dtos: [CommentDTO] = try await client.fetch(endpoint)
        return MarketMapper.comments(from: dtos)
    }

    public func trades(conditionId: String) async throws -> [ActivityTrade] {
        let endpoint = Endpoint(
            host: .data,
            path: "/trades",
            query: ["market": conditionId, "limit": "50"]
        )
        let dtos: [ActivityTradeDTO] = try await client.fetch(endpoint)
        return MarketMapper.trades(from: dtos)
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

/// Pure, testable mapper from domain query params to Gamma API query dictionary.
public enum GammaEventQuery {
    private static let pageSize = 20

    public static func params(offset: Int, tagID: String?, sort: EventSort, status: EventStatus) -> [String: String] {
        let (order, ascending) = sortParams(for: sort)
        var query: [String: String] = [
            "limit": "\(pageSize)",
            "offset": "\(offset)",
            "order": order,
            "ascending": ascending,
        ]
        if status == .active {
            query["active"] = "true"
            query["closed"] = "false"
        }
        if let tagID { query["tag_id"] = tagID }
        return query
    }

    private static func sortParams(for sort: EventSort) -> (order: String, ascending: String) {
        switch sort {
        case .volume24h:   return ("volume24hr", "false")
        case .liquidity:   return ("liquidity",  "false")
        case .newest:      return ("startDate",  "false")
        case .endingSoon:  return ("endDate",    "true")
        case .competitive: return ("competitive","false")
        }
    }
}

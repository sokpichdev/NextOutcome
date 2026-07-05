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

/// The live implementation of `MarketRepository`, backed by Polymarket's Gamma and Data
/// APIs. Each method builds an `Endpoint`, fetches via `APIClient`, and maps DTOs to domain
/// types with `MarketMapper`. Query-string construction lives in the separate, testable
/// `GammaEventQuery` helper.
public struct GammaMarketRepository: MarketRepository {
    /// The shared API client used for all requests.
    private let client: APIClient

    /// Creates the repository.
    /// - Parameter client: The shared `APIClient`.
    public init(client: APIClient) {
        self.client = client
    }

    /// Page size for cursor pagination (also how the next cursor is derived).
    private static let pageSize = 10

    /// Fetches one page of events from Gamma `/events`, applying the tag/sort/status filters.
    public func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus) async throws -> Page<Event> {
        let offset = cursor.flatMap(Int.init) ?? 0
        let query = GammaEventQuery.params(offset: offset, tagID: tagID, sort: sort, status: status)
        let endpoint = Endpoint(host: .gamma, path: "/events", query: query)
        let dtos: [EventDTO] = try await client.fetch(endpoint)
        let events = dtos.map(MarketMapper.event(from:))
        let nextCursor = dtos.count == Self.pageSize ? "\(offset + Self.pageSize)" : nil
        return Page(items: events, nextCursor: nextCursor)
    }

    /// Fetches one page of markets by flattening the markets out of an events page.
    public func fetchMarkets(cursor: String?) async throws -> Page<Market> {
        let offset = cursor.flatMap(Int.init) ?? 0
        let endpoint = Endpoint(host: .gamma, path: "/events", query: GammaEventQuery.params(offset: offset, tagID: nil, sort: .volume24h, status: .active))
        let dtos: [EventDTO] = try await client.fetch(endpoint)
        let markets = dtos.flatMap { $0.markets }.map(MarketMapper.market(from:))
        let nextCursor = dtos.count == Self.pageSize ? "\(offset + Self.pageSize)" : nil
        return Page(items: markets, nextCursor: nextCursor)
    }

    /// Fetches a single event by slug, throwing `APIError.badURL` if none matches.
    public func fetchEvent(slug: String) async throws -> Event {
        let endpoint = Endpoint(host: .gamma, path: "/events", query: ["slug": slug])
        let dtos: [EventDTO] = try await client.fetch(endpoint)
        guard let dto = dtos.first else { throw APIError.badURL }
        return MarketMapper.event(from: dto)
    }

    /// Full-text searches markets via Gamma `/public-search`, decoding only the markets
    /// array out of the composite search envelope.
    public func searchMarkets(query: String) async throws -> [Market] {
            let endpoint = Endpoint(
                host: .gamma,
                path: "/public-search",
                query: ["term": query, "type": "markets"]
            )
            // Search returns a composite envelope — decode markets array only
            struct SearchEnvelope: Decodable { let markets: [MarketDTO] }
            let envelope: SearchEnvelope = try await client.fetch(endpoint)
            // No documented `limit` param on /public-search; cap client-side.
            return envelope.markets.prefix(10).map(MarketMapper.market(from:))
        }

    /// Fetches the top holders of a market's condition from Data `/holders`.
    public func holders(conditionId: String) async throws -> [Holder] {
        let endpoint = Endpoint(
            host: .data,
            path: "/holders",
            query: ["market": conditionId, "limit": "10"]
        )
        let groups: [HolderGroupDTO] = try await client.fetch(endpoint)
        return MarketMapper.holders(from: groups)
    }

    /// Fetches an event's comments from Gamma `/comments`.
    public func comments(eventID: String) async throws -> [Comment] {
        let endpoint = Endpoint(
            host: .gamma,
            path: "/comments",
            query: ["parent_entity_type": "Event", "parent_entity_id": eventID, "limit": "10"]
        )
        let dtos: [CommentDTO] = try await client.fetch(endpoint)
        return MarketMapper.comments(from: dtos)
    }

    /// Fetches recent trades for a market's condition from Data `/trades`.
    public func trades(conditionId: String) async throws -> [ActivityTrade] {
        let endpoint = Endpoint(
            host: .data,
            path: "/trades",
            query: ["market": conditionId, "limit": "10"]
        )
        let dtos: [ActivityTradeDTO] = try await client.fetch(endpoint)
        return MarketMapper.trades(from: dtos)
    }

    /// Fetches all events of a series (tournament), walking up to 3 pages of 100.
    public func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] {
        // A series (tournament) is bounded but can exceed one page; walk a few pages.
        var all: [SeriesEventDTO] = []
        for page in 0..<3 {
            let query = GammaEventQuery.seriesParams(seriesID: seriesID, offset: page * 100, status: status)
            let dtos: [SeriesEventDTO] = try await client.fetch(Endpoint(host: .gamma, path: "/events", query: query))
            all += dtos
            if dtos.count < 100 { break }
        }
        return all.map { $0.toDomain() }
    }

    /// Fetches live/final results for a batch of events, one request per id with a bounded
    /// concurrency of 8 (a sliding window), skipping ids that fail or return nothing.
    public func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] {
        // Multi-id support on /events/results is undocumented, so fetch per id with bounded
        // concurrency; a failed or empty id is skipped rather than failing the batch.
        try await withThrowingTaskGroup(of: (String, GameResult?).self) { group in
            var results: [String: GameResult] = [:]
            var pending = eventIDs.makeIterator()
            var inFlight = 0

            // Starts the next pending request if any remain, tracking the in-flight count.
            func addNext() {
                guard let id = pending.next() else { return }
                inFlight += 1
                group.addTask {
                    let endpoint = Endpoint(host: .gamma, path: "/events/results", query: ["id": id])
                    let dtos: [GameResultDTO]? = try? await client.fetch(endpoint)
                    return (id, dtos?.first?.toDomain(fallbackEventID: id))
                }
            }

            for _ in 0..<8 { addNext() }
            while inFlight > 0 {
                guard let (id, result) = try await group.next() else { break }
                inFlight -= 1
                if let result { results[id] = result }
                addNext()
            }
            return results
        }
    }

    /// Fetches the most-recently-closed events of a series (ordered by end date, descending).
    public func fetchCompletedEvents(seriesID: String, limit: Int) async throws -> [Event] {
        let query: [String: String] = [
            "series_id": seriesID, "closed": "true",
            "order": "endDate", "ascending": "false", "limit": "\(limit)",
        ]
        let dtos: [SeriesEventDTO] = try await client.fetch(Endpoint(host: .gamma, path: "/events", query: query))
        return dtos.map { $0.toDomain() }
    }

    /// Fetches team reference data for a league from Gamma `/teams`.
    public func fetchTeams(league: String) async throws -> [GameTeam] {
        let endpoint = Endpoint(host: .gamma, path: "/teams", query: ["league": league, "limit": "500"])
        let dtos: [GameTeamDTO] = try await client.fetch(endpoint)
        return dtos.compactMap { $0.toDomain() }
    }

    /// Fetches the carousel filter tags from Gamma `/tags`.
    public func fetchTags() async throws -> [Tag] {
        let endpoint = Endpoint(
            host: .gamma,
            path: "/tags",
            query: ["limit": "10", "is_carousel": "true"]
        )
        let dtos: [TagDTO] = try await client.fetch(endpoint)
        return dtos.map(MarketMapper.tag(from:))
    }
}

/// Pure, testable mapper from domain query params to Gamma API query dictionary.
public enum GammaEventQuery {
    /// The page size used for the events list query.
    private static let pageSize = 10

    /// Builds the query dictionary for the paged `/events` list.
    /// - Parameters:
    ///   - offset: The pagination offset.
    ///   - tagID: An optional tag filter.
    ///   - sort: The sort order (mapped to Gamma's order/ascending params).
    ///   - status: When `.active`, restricts to open, non-closed events.
    /// - Returns: The query dictionary.
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

    /// Params for fetching a whole series (tournament) in bounded 100-item pages.
    public static func seriesParams(seriesID: String, offset: Int, status: EventStatus) -> [String: String] {
        var query: [String: String] = [
            "series_id": seriesID,
            "limit": "100",
            "offset": "\(offset)",
        ]
        if status == .active {
            query["closed"] = "false"
        }
        return query
    }

    /// Maps a domain `EventSort` to Gamma's `(order, ascending)` query values.
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

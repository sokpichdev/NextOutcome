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
    /// Caches the navigation rows so switching categories doesn't re-request them.
    private let relatedTagsCache: RelatedTagsCache
    /// Caches the curated featured list so every cold feed load doesn't re-request it.
    private let featuredEventsCache: FeaturedEventsCache

    /// Creates the repository.
    /// - Parameters:
    ///   - client: The shared `APIClient`.
    ///   - relatedTagsCache: Caches the nav rows. The default gives one instance per
    ///     repository, which is per-app in practice since `AppContainer` builds one.
    ///   - featuredEventsCache: Caches the curated featured list, same lifetime story.
    public init(
        client: APIClient,
        relatedTagsCache: RelatedTagsCache = RelatedTagsCache(),
        featuredEventsCache: FeaturedEventsCache = FeaturedEventsCache()
    ) {
        self.client = client
        self.relatedTagsCache = relatedTagsCache
        self.featuredEventsCache = featuredEventsCache
    }

    /// Page size for cursor pagination (also how the next cursor is derived).
    private static let pageSize = 10

    /// Fetches one page of events from Gamma `/events/keyset`, applying the
    /// tag/sort/status/period filters.
    ///
    /// Uses cursor pagination rather than offsets. The feed is sorted by `volume24hr`, which
    /// changes continuously, so an offset window slides between requests — events duplicate
    /// across pages or get skipped entirely. The opaque cursor pins the last row's sort
    /// position instead, so consecutive pages never overlap. `Page.nextCursor` is now Gamma's
    /// real `next_cursor` rather than a count-derived guess, so "is there more?" is answered
    /// by the server instead of inferred from a full page.
    public func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> {
        let query = GammaEventQuery.keysetParams(cursor: cursor, tagID: tagID, sort: sort, status: status, period: period)
        let endpoint = Endpoint(host: .gamma, path: "/events/keyset", query: query)
        let page: EventKeysetPageDTO = try await client.fetch(endpoint)
        return Page(items: page.events.map(MarketMapper.event(from:)), nextCursor: page.nextCursor)
    }

    /// Fetches Polymarket's curated featured list — the editorial ranking the web homepage
    /// pins above its volume-sorted feed. Served from a 5-minute cache.
    public func fetchFeaturedEvents(limit: Int) async throws -> [Event] {
        if let cached = await featuredEventsCache.value() { return cached }
        let endpoint = Endpoint(host: .gamma, path: "/events/keyset", query: GammaEventQuery.featuredParams(limit: limit))
        let page: EventKeysetPageDTO = try await client.fetch(endpoint)
        let events = page.events.map(MarketMapper.event(from:))
        await featuredEventsCache.store(events)
        return events
    }

    /// Fetches one page of markets by flattening the markets out of an events page.
    public func fetchMarkets(cursor: String?) async throws -> Page<Market> {
        let offset = cursor.flatMap(Int.init) ?? 0
        let endpoint = Endpoint(host: .gamma, path: "/events", query: GammaEventQuery.params(offset: offset, tagID: nil, sort: .volume24h, status: .active, period: .all))
        let dtos: [EventDTO] = try await client.fetch(endpoint)
        let markets = dtos.flatMap { $0.markets }.map(MarketMapper.market(from:))
        let nextCursor = dtos.count == Self.pageSize ? "\(offset + Self.pageSize)" : nil
        return Page(items: markets, nextCursor: nextCursor)
    }

    /// Fetches the biggest 24h movers for the Breaking feed from Gamma `/markets`.
    ///
    /// Gamma can only sort by `oneDayPriceChange` in one direction at a time, so this pulls the
    /// biggest *losers* (ascending) and biggest *gainers* (descending) in parallel, then ranks
    /// them with `MoverRanking` (de-dupe, denoise, sort by move magnitude) — interleaving up
    /// and down movers like the site.
    public func movers(tagID: String?) async throws -> [Mover] {
        async let losers: [MoverDTO] = client.fetch(Endpoint(host: .gamma, path: "/markets", query: GammaMoversQuery.params(tagID: tagID, ascending: true)))
        async let gainers: [MoverDTO] = client.fetch(Endpoint(host: .gamma, path: "/markets", query: GammaMoversQuery.params(tagID: tagID, ascending: false)))
        let combined = try await losers + gainers
        return MoverRanking.rank(combined.map(MarketMapper.mover(from:)))
    }

    /// Fetches a single event by slug, throwing `APIError.badURL` if none matches.
    public func fetchEvent(slug: String) async throws -> Event {
        let endpoint = Endpoint(host: .gamma, path: "/events", query: ["slug": slug])
        let dtos: [EventDTO] = try await client.fetch(endpoint)
        guard let dto = dtos.first else { throw APIError.badURL }
        return MarketMapper.event(from: dto)
    }

    /// Full-text searches markets via Gamma `/public-search`, decoding only the markets
    /// array out of the composite search envelope. The query param is `q`, not `term` —
    /// `term` silently 400s (`{"type":"validation error","error":"query argument \"q\": empty"}`).
    public func searchMarkets(query: String) async throws -> [Market] {
        let endpoint = Endpoint(
            host: .gamma,
            path: "/public-search",
            query: ["q": query, "type": "markets", "limit_per_type": "10"]
        )
        // Search returns a composite envelope — decode markets array only
        struct SearchEnvelope: Decodable { let markets: [MarketDTO] }
        let envelope: SearchEnvelope = try await client.fetch(endpoint)
        return envelope.markets.map(MarketMapper.market(from:))
    }

    /// Full-text searches events via Gamma `/public-search`, decoding only the events array.
    public func searchEvents(query: String) async throws -> [Event] {
        let endpoint = Endpoint(
            host: .gamma,
            path: "/public-search",
            query: ["q": query, "type": "events", "limit_per_type": "10"]
        )
        // `events` is optional on purpose: when nothing matches, Gamma omits the key
        // entirely and returns just `{"pagination": …}`. Decoding it as required turned
        // every no-match query into a thrown error, so the UI showed "Search failed"
        // where it should have shown "No results".
        struct SearchEnvelope: Decodable { let events: [EventDTO]? }
        let envelope: SearchEnvelope = try await client.fetch(endpoint)
        return (envelope.events ?? []).map(MarketMapper.event(from:))
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

    /// Fetches an event's comments from Gamma `/comments`, sorted and optionally
    /// restricted to commenters holding a position (`holders_only`).
    public func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] {
        var query = [
            "parent_entity_type": "Event", "parent_entity_id": eventID, "limit": "20",
            "order": sort == .mostLiked ? "reactionCount" : "createdAt", "ascending": "false",
        ]
        if holdersOnly { query["holders_only"] = "true" }
        let endpoint = Endpoint(host: .gamma, path: "/comments", query: query)
        let dtos: [CommentDTO] = try await client.fetch(endpoint)
        return MarketMapper.comments(from: dtos)
    }

    /// Fetches recent trades for a market's condition from Data `/trades`.
    /// `/trades` is a live feed but sits behind a Cloudflare edge cache
    /// (`cache-control: public, max-age=300`) that's keyed on the full URL — polling the
    /// same query repeatedly just re-serves a stale cached response for up to 5 minutes.
    /// A changing `_` param busts the cache so every poll actually reaches the origin.
    public func trades(conditionId: String) async throws -> [ActivityTrade] {
        let endpoint = Endpoint(
            host: .data,
            path: "/trades",
            query: ["market": conditionId, "limit": "10", "_": "\(Date().timeIntervalSince1970)"]
        )
        let dtos: [ActivityTradeDTO] = try await client.fetch(endpoint)
        return MarketMapper.trades(from: dtos)
    }

    /// Fetches a user's positions in an event from Data `/positions`, for the comment
    /// "holder" badge. `user` must be the proxy (trading) wallet, not the base address.
    public func commenterPositions(proxyWallet: String, eventID: String) async throws -> [CommentHolding] {
        let endpoint = Endpoint(
            host: .data,
            path: "/positions",
            query: ["user": proxyWallet, "eventId": eventID]
        )
        let dtos: [CommentHoldingDTO] = try await client.fetch(endpoint)
        return MarketMapper.commentHoldings(from: dtos)
    }

    /// Fetches all events of a series (tournament), walking up to 3 pages of 100.
    public func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] {
        // A series (tournament) is bounded but can exceed one page; walk a few pages.
        var all: [EventDTO] = []
        for page in 0..<3 {
            let query = GammaEventQuery.seriesParams(seriesID: seriesID, offset: page * 100, status: status)
            let dtos: [EventDTO] = try await client.fetch(Endpoint(host: .gamma, path: "/events", query: query))
            all += dtos
            if dtos.count < 100 { break }
        }
        return all.map(MarketMapper.event(from:))
    }

    /// Fetches all events under a tag (e.g. the Politics hub's "midterms" tag), walking up to
    /// 5 pages of 100 — bounded like `fetchEvents(seriesID:status:)`, but keyed by tag instead.
    public func fetchAllEvents(tagID: String, status: EventStatus) async throws -> [Event] {
        var all: [EventDTO] = []
        for page in 0..<5 {
            let query = GammaEventQuery.tagParams(tagID: tagID, offset: page * 100, status: status)
            let dtos: [EventDTO] = try await client.fetch(Endpoint(host: .gamma, path: "/events", query: query))
            all += dtos
            if dtos.count < 100 { break }
        }
        return all.map(MarketMapper.event(from:))
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
        let dtos: [EventDTO] = try await client.fetch(Endpoint(host: .gamma, path: "/events", query: query))
        return dtos.map(MarketMapper.event(from:))
    }

    /// Fetches team reference data for a league from Gamma `/teams`.
    public func fetchTeams(league: String) async throws -> [GameTeam] {
        let endpoint = Endpoint(host: .gamma, path: "/teams", query: ["league": league, "limit": "500"])
        let dtos: [GameTeamDTO] = try await client.fetch(endpoint)
        return dtos.compactMap { $0.toDomain() }
    }

    /// The raw catalogue: `/sports` rows paired with the `/sports/summary` activity map.
    ///
    /// The two calls are concurrent because neither depends on the other and the summary is
    /// the larger payload (~100KB); serialising them would add its latency to every hub
    /// load. They join on the league slug — `/sports` calls it `sport`, `/sports/summary`
    /// uses it as the dictionary key.
    ///
    /// Kept at DTO level so `fetchLeagues(tagID:)` can filter on the raw tag list, which the
    /// domain entity deliberately doesn't carry.
    private func rawCatalogue() async throws -> (rows: [SportLeagueDTO], activity: [String: SportsSummaryDTO.League]) {
        async let leagues: [SportLeagueDTO] = client.fetch(Endpoint(host: .gamma, path: "/sports"))
        async let summary: SportsSummaryDTO = client.fetch(Endpoint(host: .gamma, path: "/sports/summary"))
        let (rows, activity) = try await (leagues, summary)
        return (rows, activity.leagues)
    }

    /// Fetches one keyset page of sports games, in-play or upcoming.
    ///
    /// Uses the same `/events/keyset` shape as the main feed, so paging behaves identically —
    /// only the filters differ. Gamma's variant markets ("Halftime Result", "Exact Score")
    /// come back alongside each fixture and are dropped downstream by the moneyline rule,
    /// which is what keeps one card per game.
    public func fetchSportsGames(
        live: Bool, startingAfter: Date?, cursor: String?, leagueTagID: String?
    ) async throws -> Page<Event> {
        let params = GammaEventQuery.sportsGamesParams(
            live: live, startingAfter: startingAfter, cursor: cursor, leagueTagID: leagueTagID
        )
        let page: EventKeysetPageDTO = try await client.fetch(
            Endpoint(host: .gamma, path: "/events/keyset", query: params.query, extraQueryItems: params.extraItems)
        )
        return Page(items: page.events.map(MarketMapper.event(from:)), nextCursor: page.nextCursor)
    }

    /// Fetches one keyset page of esports matches, in-play or upcoming.
    ///
    /// Shares the `/events/keyset` shape with `fetchSportsGames`, so paging behaves identically
    /// across both hubs — only the tag filters differ.
    public func fetchEsportsGames(
        live: Bool, startingAfter: Date?, cursor: String?, leagueTagID: String?
    ) async throws -> Page<Event> {
        let params = GammaEventQuery.esportsGamesParams(
            live: live, startingAfter: startingAfter, cursor: cursor, leagueTagID: leagueTagID
        )
        let page: EventKeysetPageDTO = try await client.fetch(
            Endpoint(host: .gamma, path: "/events/keyset", query: params.query, extraQueryItems: params.extraItems)
        )
        return Page(items: page.events.map(MarketMapper.event(from:)), nextCursor: page.nextCursor)
    }

    /// Fetches Gamma's full league catalogue with activity merged in.
    ///
    /// Neither endpoint takes parameters, so scoping happens here. It isn't cached: rows
    /// change on the order of weeks, and pull-to-refresh re-reading it is correct behaviour.
    public func fetchSportsCatalogue() async throws -> [SportLeague] {
        let (rows, activity) = try await rawCatalogue()
        return rows.compactMap { $0.toDomain(summary: activity[$0.sport]) }
    }

    /// Fetches the catalogue, keeping only leagues whose raw `/sports` tag list contains
    /// `tagID` — how the Esports hub scopes it to game titles (tag `64`).
    public func fetchLeagues(tagID: String) async throws -> [SportLeague] {
        let (rows, activity) = try await rawCatalogue()
        return rows.filter { $0.tagIDs.contains(tagID) }
            .compactMap { $0.toDomain(summary: activity[$0.sport]) }
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

    /// Fetches a single tag by its URL slug from Gamma `/tags/slug/{slug}` (a single JSON
    /// object, unlike the array-returning `/tags`). Used to resolve a curated home-rail
    /// category to its live tag id at runtime. Propagates any transport/HTTP error (e.g.
    /// a 404 for an unknown slug) — callers decide whether to swallow it.
    public func fetchTag(slug: String) async throws -> Tag? {
        let endpoint = Endpoint(host: .gamma, path: "/tags/slug/\(slug)")
        let dto: TagDTO = try await client.fetch(endpoint)
        return MarketMapper.tag(from: dto)
    }

    /// Fetches the tags related to `slug` from Gamma `/tags/slug/{slug}/related-tags/tags`,
    /// in the server's rank order, served from `relatedTagsCache` when still fresh.
    ///
    /// The trailing `/tags` matters: the shorter `/related-tags` returns bare relationship
    /// records (`tagID`/`relatedTagID`/`rank`) with no labels or slugs, which is unusable for
    /// rendering a chip. `status=active` is sent for forward-compatibility only — today Gamma
    /// returns the same rows for `active`, `closed` and no value at all, so callers still have
    /// to drop dead tags by `activeEventsCount` themselves.
    public func fetchRelatedTags(slug: String) async throws -> [Tag] {
        if let cached = await relatedTagsCache.value(for: slug) { return cached }
        let endpoint = Endpoint(
            host: .gamma,
            path: "/tags/slug/\(slug)/related-tags/tags",
            query: ["status": "active"]
        )
        let dtos: [TagDTO] = try await client.fetch(endpoint)
        let tags = dtos.map(MarketMapper.tag(from:))
        await relatedTagsCache.store(tags, for: slug)
        return tags
    }
}

/// Pure, testable mapper from domain query params to Gamma API query dictionary.
public enum GammaEventQuery {
    /// The page size used for the offset-paged `/events` queries (`fetchMarkets`).
    private static let pageSize = 10
    /// The page size used for the cursor-paged feed, matching the web client's `limit=20`.
    private static let keysetPageSize = 20

    /// Builds the query dictionary for the paged `/events` list.
    /// - Parameters:
    ///   - offset: The pagination offset.
    ///   - tagID: An optional tag filter.
    ///   - sort: The sort order (mapped to Gamma's order/ascending params).
    ///   - status: Which events to include by lifecycle status.
    ///   - period: How far back an event must have started to be included.
    /// - Returns: The query dictionary.
    public static func params(offset: Int, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod = .all) -> [String: String] {
        var query = sharedParams(tagID: tagID, sort: sort, status: status, period: period)
        query["limit"] = "\(pageSize)"
        query["offset"] = "\(offset)"
        return query
    }

    /// Builds the query dictionary for the cursor-paged `/events/keyset` feed.
    ///
    /// Keyset is what the Polymarket web client uses, and it's the only correct way to page
    /// a `volume24hr`-sorted list: volumes move constantly, so an offset window slides under
    /// you between requests and the same event can appear on two pages or none. The cursor
    /// encodes the last row's sort position instead, so pages never overlap.
    ///
    /// `offset` must never be sent — keyset endpoints reject it outright with HTTP 422
    /// (`"offset is not allowed on keyset endpoints"`).
    /// - Parameters:
    ///   - cursor: The opaque `next_cursor` from the previous page, or `nil` for the first.
    ///   - tagID: An optional tag filter.
    ///   - sort: The sort order (mapped to Gamma's order/ascending params).
    ///   - status: Which events to include by lifecycle status.
    ///   - period: How far back an event must have started to be included.
    /// - Returns: The query dictionary.
    public static func keysetParams(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod = .all) -> [String: String] {
        var query = sharedParams(tagID: tagID, sort: sort, status: status, period: period)
        query["limit"] = "\(keysetPageSize)"
        if let cursor, !cursor.isEmpty { query["after_cursor"] = cursor }
        return query
    }

    /// Gamma's "Games" tag — the one real fixtures carry, as opposed to season futures.
    static let gamesTagID = "100639"
    /// The esports tag, excluded server-side: esports has its own hub, and the Sports chip row
    /// already filters it, so showing its matches in this feed would contradict the chips.
    static let esportsTagID = "64"

    /// Builds the Sports hub's games query.
    ///
    /// The hub previously read the general sports tag sorted by 24h volume, a feed dominated
    /// by season futures — measured against the live API, 20 fetched events yielded 4
    /// non-esports games and none in play. Scoping to the Games tag and excluding esports
    /// server-side is what makes the feed actually about games.
    ///
    /// - Parameters:
    ///   - live: When true, asks for in-play games only. When false the flag is omitted
    ///     entirely rather than sent as `false`, which would exclude in-play games instead of
    ///     simply not filtering on them.
    ///   - startingAfter: Lower bound on kickoff, for the upcoming feed. Supplying it also
    ///     switches the sort to kickoff order.
    ///   - cursor: The keyset cursor, or `nil`/empty for the first page.
    ///   - leagueTagID: Narrows to one sport or league. Gamma ANDs tags by *repeating*
    ///     `tag_id` — a comma list is rejected as an invalid integer — so the extra tag comes
    ///     back separately, to be sent as its own query item alongside `tag_match=all`.
    /// - Returns: The dictionary parameters plus any items that must repeat a key.
    static func sportsGamesParams(
        live: Bool, startingAfter: Date?, cursor: String?, leagueTagID: String? = nil
    ) -> (query: [String: String], extraItems: [URLQueryItem]) {
        var query: [String: String] = [
            "tag_id": gamesTagID,
            "exclude_tag_id": esportsTagID,
            "closed": "false",
            "limit": "\(keysetPageSize)",
        ]
        var extraItems: [URLQueryItem] = []
        if let leagueTagID {
            query["tag_match"] = "all"
            extraItems.append(URLQueryItem(name: "tag_id", value: leagueTagID))
        }
        if live { query["live"] = "true" }
        if let startingAfter {
            query["start_time_min"] = ISO8601DateFormatter().string(from: startingAfter)
            query["order"] = "startTime"
            query["ascending"] = "true"
        }
        if let cursor, !cursor.isEmpty { query["after_cursor"] = cursor }
        return (query, extraItems)
    }

    /// Builds the Esports hub's match query — the mirror image of `sportsGamesParams`.
    ///
    /// Same two-tag intersection, opposite side of it: the Sports feed excludes esports, this
    /// one *is* esports, ANDed with the Games tag so futures ("LCK 2026 Season Winner") never
    /// cross the wire. That intersection is what `EsportsCatalog.isMatch` used to do client-side
    /// on a 500-event download — measured against the live API, 500 fetched events yielded 410
    /// matches and 33 MB, of which 94% was market sub-objects the hub reads two fields from.
    ///
    /// Gamma ANDs tags by *repeating* `tag_id` (a comma list is rejected as an invalid integer),
    /// so the second and any league tag come back as `extraItems` rather than dictionary keys.
    ///
    /// - Parameters:
    ///   - live: When true, asks for in-play matches only. Omitted rather than sent as `false`,
    ///     which would exclude in-play matches instead of simply not filtering on them.
    ///   - startingAfter: Lower bound on kickoff, for the upcoming feed. Supplying it also
    ///     switches the sort to kickoff order.
    ///   - cursor: The keyset cursor, or `nil`/empty for the first page.
    ///   - leagueTagID: Narrows to one game title (CS2, LoL), for the tile row's filter.
    /// - Returns: The dictionary parameters plus the items that must repeat `tag_id`.
    static func esportsGamesParams(
        live: Bool, startingAfter: Date?, cursor: String?, leagueTagID: String? = nil
    ) -> (query: [String: String], extraItems: [URLQueryItem]) {
        var query: [String: String] = [
            "tag_id": esportsTagID,
            "tag_match": "all",
            "closed": "false",
            "limit": "\(keysetPageSize)",
        ]
        var extraItems = [URLQueryItem(name: "tag_id", value: gamesTagID)]
        if let leagueTagID { extraItems.append(URLQueryItem(name: "tag_id", value: leagueTagID)) }
        if live { query["live"] = "true" }
        if let startingAfter {
            query["start_time_min"] = ISO8601DateFormatter().string(from: startingAfter)
            query["order"] = "startTime"
            query["ascending"] = "true"
        }
        if let cursor, !cursor.isEmpty { query["after_cursor"] = cursor }
        return (query, extraItems)
    }

    /// The filter/sort params common to the offset and keyset list shapes.
    private static func sharedParams(tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) -> [String: String] {
        let (order, ascending) = sortParams(for: sort)
        var query: [String: String] = [
            "order": order,
            "ascending": ascending,
        ]
        switch status {
        case .active:
            query["active"] = "true"
            query["closed"] = "false"
        case .resolved:
            query["closed"] = "true"
        case .all:
            break
        }
        if let tagID { query["tag_id"] = tagID }
        if let startDateMin = startDateMin(for: period) { query["start_date_min"] = startDateMin }
        return query
    }

    /// The ISO-8601 lower bound on `startDate` for a period filter, or `nil` for `.all`.
    private static func startDateMin(for period: EventPeriod) -> String? {
        let days: Int
        switch period {
        case .daily:   days = 1
        case .weekly:  days = 7
        case .monthly: days = 30
        case .all:     return nil
        }
        let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return ISO8601DateFormatter().string(from: date)
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

    /// Params for fetching all events under a tag (e.g. Politics hub's "midterms" tag) in
    /// bounded 100-item pages.
    ///
    /// `order` is load-bearing despite every caller re-sorting client-side. The fetch is
    /// capped at 5 pages, so the order decides *which 500 events the hub ever sees* — and
    /// Gamma's default is creation order, which fills the window with the oldest rows in the
    /// tag. Measured on the Crypto tag: the unordered window spanned 2024-12-31 → 2026-08-02
    /// and its head was airdrop markets trading $0–105/day, while the tag's real leaders
    /// trade $500k+. Sorting by 24h volume makes the cap select the events that matter.
    public static func tagParams(tagID: String, offset: Int, status: EventStatus) -> [String: String] {
        var query: [String: String] = [
            "tag_id": tagID,
            "limit": "100",
            "offset": "\(offset)",
            "order": "volume24hr",
            "ascending": "false",
        ]
        if status == .active {
            query["closed"] = "false"
        }
        return query
    }

    /// Params for Polymarket's curated "featured" list — the hand-ranked editorial order the
    /// web homepage pins above its algorithmic feed.
    ///
    /// `featured_order=true` is what switches Gamma into that ranking; `order=featuredOrder`
    /// with `ascending=true` then reads it lowest-first, so `featuredOrder: 1` comes back
    /// first. This is a curated list, not a computed one — it does not respond to volume.
    /// - Parameter limit: How many rows to request.
    /// - Returns: The query dictionary.
    public static func featuredParams(limit: Int) -> [String: String] {
        [
            "limit": "\(limit)",
            "order": "featuredOrder",
            "featured_order": "true",
            "ascending": "true",
            "active": "true",
            "closed": "false",
            "archived": "false",
        ]
    }

    /// Maps a domain `EventSort` to Gamma's `(order, ascending)` query values.
    private static func sortParams(for sort: EventSort) -> (order: String, ascending: String) {
        switch sort {
        case .volume24h:   return ("volume24hr", "false")
        case .volume1wk:   return ("volume1wk",  "false")
        case .volume1mo:   return ("volume1mo",  "false")
        case .volumeTotal: return ("volume",     "false")
        case .liquidity:   return ("liquidity",  "false")
        case .newest:      return ("startDate",  "false")
        case .endingSoon:  return ("endDate",    "true")
        case .competitive: return ("competitive","false")
        case .closedTime:  return ("closedTime", "false")
        }
    }
}

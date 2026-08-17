//
//  MarketRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation
import SharedDomain

/// Read access to Polymarket's market/event catalogue and the social data around it
/// (holders, comments, trades). The concrete implementation lives in the Data layer; the
/// Domain and Presentation layers only ever see this protocol.
public protocol MarketRepository: Sendable {
    /// Fetches one page of events, optionally filtered by tag, sorted/scoped, and bounded
    /// to events that started within `period`.
    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event>
    /// Polymarket's curated "featured" list, in editorial rank order (`featuredOrder` 1 first).
    ///
    /// This is a hand-maintained ranking, not a computed one — it's what the web homepage
    /// pins above its volume-sorted feed, and it's the reason the web leads with headline
    /// markets while a raw `volume24hr` feed leads with whatever sports fixture traded most.
    func fetchFeaturedEvents(limit: Int) async throws -> [Event]
    /// All events of a Gamma series (e.g. a tournament). Bounded, unpaginated.
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event]
    /// All events under a Gamma tag (e.g. the "midterms" tag). Bounded, unpaginated — for hub
    /// screens (like Politics) that need the full set at once rather than a scrolling page.
    func fetchAllEvents(tagID: String, status: EventStatus) async throws -> [Event]
    /// Live/final scores for game events, keyed by event id. Missing ids are simply absent.
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult]
    /// Team reference data (name, logo, colour) for a sports league, e.g. "fifwc".
    func fetchTeams(league: String) async throws -> [GameTeam]
    /// One page of sports *games* — real fixtures, esports excluded.
    ///
    /// Separate from `fetchEvents` because the Sports feed needs filters no other feed wants
    /// (games-only, esports-excluded, in-play, kickoff-bounded); folding them into the general
    /// query would burden every caller with sports concerns.
    /// - Parameters:
    ///   - live: Ask for in-play games only.
    ///   - startingAfter: Lower bound on kickoff; also sorts by kickoff ascending.
    ///   - cursor: Keyset cursor, `nil` for the first page.
    ///   - leagueTagID: Narrows to one sport or league; `nil` for the whole feed.
    func fetchSportsGames(live: Bool, startingAfter: Date?, cursor: String?, leagueTagID: String?) async throws -> Page<Event>
    /// One page of esports *matches* — the mirror of `fetchSportsGames`, scoped to the esports
    /// tag instead of excluding it.
    ///
    /// Separate rather than a flag on `fetchSportsGames` because the two feeds are opposites,
    /// not variants: one means "games that aren't esports", the other "games that are". The
    /// server-side games filter is what keeps season futures off the wire, which is the whole
    /// reason the Esports hub no longer downloads its tag in bulk.
    /// - Parameters:
    ///   - live: Ask for in-play matches only.
    ///   - startingAfter: Lower bound on kickoff; also sorts by kickoff ascending.
    ///   - cursor: Keyset cursor, `nil` for the first page.
    ///   - leagueTagID: Narrows to one game title; `nil` for every game.
    func fetchEsportsGames(live: Bool, startingAfter: Date?, cursor: String?, leagueTagID: String?) async throws -> Page<Event>
    /// Gamma's full league catalogue — every league Polymarket runs markets for, with its
    /// display name, key art, classification tag, sport group, and current activity.
    ///
    /// Joined from two endpoints (`/sports` for identity, `/sports/summary` for activity)
    /// because neither alone is enough: the first has no counts, the second has no tags.
    func fetchSportsCatalogue() async throws -> [SportLeague]
    /// Gamma's league catalogue, scoped to the leagues carrying `tagID`.
    ///
    /// One endpoint returns every league Polymarket runs markets for, each with its display
    /// name, key art and the tag id that identifies its events. Passing the esports tag yields
    /// the game titles behind the Esports hub's tiles.
    func fetchLeagues(tagID: String) async throws -> [EsportsLeague]
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
    /// Fetches a single tag by its URL slug (e.g. resolving a curated home-rail category
    /// to its live Gamma tag id at runtime), or `nil` if no tag exists at that slug.
    func fetchTag(slug: String) async throws -> Tag?
    /// Fetches the tags related to the tag at `slug`, in Gamma's server-assigned rank order.
    ///
    /// This is how both navigation rows are sourced: a row *is* a curated tag whose related
    /// tags are its entries. Passing `"top-navbar"` yields the top-level category rail;
    /// passing a category's own slug yields that category's sub-topic carousel. An empty
    /// result is a normal answer (several categories genuinely have no sub-topics), not an
    /// error — the row simply doesn't render.
    func fetchRelatedTags(slug: String) async throws -> [Tag]
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
    func fetchLeagues(tagID: String) async throws -> [EsportsLeague] { [] }
    func fetchSportsCatalogue() async throws -> [SportLeague] { [] }
    func fetchSportsGames(live: Bool, startingAfter: Date?, cursor: String?, leagueTagID: String?) async throws -> Page<Event> {
        Page(items: [], nextCursor: nil)
    }
    func fetchEsportsGames(live: Bool, startingAfter: Date?, cursor: String?, leagueTagID: String?) async throws -> Page<Event> {
        Page(items: [], nextCursor: nil)
    }
    func fetchFeaturedEvents(limit: Int) async throws -> [Event] { [] }
    func fetchCompletedEvents(seriesID: String, limit: Int) async throws -> [Event] { [] }
    func fetchAllEvents(tagID: String, status: EventStatus) async throws -> [Event] { [] }
    func searchEvents(query: String) async throws -> [Event] { [] }
    func commenterPositions(proxyWallet: String, eventID: String) async throws -> [CommentHolding] { [] }
    func movers(tagID: String?) async throws -> [Mover] { [] }
    func fetchTag(slug: String) async throws -> Tag? { nil }
    func fetchRelatedTags(slug: String) async throws -> [Tag] { [] }
}

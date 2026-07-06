//
//  SportsHubViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 06/07/2026.
//

import Foundation
import MarketsDomain
import SharedDomain

/// Drives the Sports hub: the Live/Futures mode switch, the league chip row (World Cup,
/// Wimbledon, MLB, UFC, Combat, …), the live feed grouped by league, and the Futures
/// sport picker (NBA/EPL) with its ranked markets.
@MainActor
@Observable
public final class SportsHubViewModel {
    /// The hub's overall load state.
    public enum State: Equatable {
        /// Nothing loaded yet.
        case idle
        /// Loading the hub's data.
        case loading
        /// Data loaded.
        case loaded
        /// The load failed, with a user-facing message.
        case failed(String)
    }

    /// Which top-level mode the hub is showing.
    public enum Mode: Equatable {
        /// Live/upcoming games grouped by league.
        case live
        /// Futures markets (season winners, MVP, etc.) for a selected sport.
        case futures
    }

    /// The general "Sports" tag — same id `EventListViewModel.tagID(for:)` uses for
    /// `.sports`, backing the Live tab's aggregate feed.
    static let sportsTagID = "1"
    /// How many pages of the general sports feed to sample (the API pages at 10 events each)
    /// before deriving league/sport chips — enough to surface more than just the highest-volume
    /// league without an unbounded fetch.
    static let liveSamplePages = 6

    /// League chip keywords (matched as a case-insensitive substring against the sample's
    /// event tags, e.g. "world cup" matches the real tag label "FIFA World Cup") and their
    /// chip glyph, in the order they should appear. World Cup routes into the existing
    /// `WorldCupHubView` rather than a generic league detail screen.
    static let knownLeagues: [(label: String, glyph: String)] = [
        ("World Cup", "soccerball"),
        ("Wimbledon", "figure.tennis"),
        ("MLB", "baseball.fill"),
        ("UFC", "figure.martial.arts"),
        ("Combat", "figure.boxing"),
    ]

    /// Futures sport-picker keywords and glyphs, in display order.
    static let knownFuturesSports: [(label: String, glyph: String)] = [
        ("NBA", "basketball.fill"),
        ("EPL", "soccerball"),
    ]

    /// The current load state.
    public private(set) var state: State = .idle
    /// The selected top-level mode.
    public var mode: Mode = .live
    /// League chips resolved from the live sample's event tags, for navigation into
    /// per-league detail.
    public private(set) var leagues: [SportsLeague] = []
    /// Live events grouped by league, in `leagues` order; leagues with no live events are omitted.
    public private(set) var liveGroups: [(league: SportsLeague, events: [Event])] = []
    /// Sport chips for the Futures picker (NBA/EPL), resolved from the same sample.
    public private(set) var futuresSports: [SportsLeague] = []
    /// The selected Futures sport's tag id.
    public var selectedFuturesSportID: String?
    /// The selected Futures sport's markets (season winner, MVP, etc.), highest volume first.
    public private(set) var futuresEvents: [Event] = []
    /// When the hub's data was last refreshed.
    public private(set) var lastUpdated: Date?

    /// Loads a page of events, optionally by tag.
    private let fetchEvents: FetchEventsUseCase
    /// Injectable clock (defaults to `Date()`), for deterministic tests.
    private let now: @Sendable () -> Date

    /// Creates the view model with its use cases.
    public init(
        fetchEvents: FetchEventsUseCase,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fetchEvents = fetchEvents
        self.now = now
    }

    /// Loads on first appearance only (no-op once loaded/loading).
    public func loadIfNeeded() async {
        if case .idle = state { await load() }
    }

    /// Samples several pages of the general sports feed, derives the league/sport chips from
    /// the sample's own event tags (the tag catalogue endpoint only returns a curated top-nav
    /// set and never includes league-specific tags — see `TrendingChipDeriver`), groups the
    /// sample into the Live tab's sections, then kicks off the initial Futures fetch.
    public func load() async {
        state = .loading
        let events = await Self.fetchSample(fetchEvents, pages: Self.liveSamplePages)
        guard !events.isEmpty else {
            state = .failed("Couldn't load Sports. Pull to refresh.")
            return
        }
        leagues = Self.resolve(Self.knownLeagues, in: events)
        futuresSports = Self.resolve(Self.knownFuturesSports, in: events)
        if selectedFuturesSportID == nil || !futuresSports.contains(where: { $0.id == selectedFuturesSportID }) {
            selectedFuturesSportID = futuresSports.first?.id
        }
        liveGroups = Self.grouped(events, into: leagues)
        state = .loaded
        lastUpdated = now()
        await loadFutures()
    }

    /// Reloads everything (pull-to-refresh).
    public func refresh() async {
        await load()
    }

    /// Selects a Futures sport chip and reloads its markets, unless already selected.
    public func selectFuturesSport(_ tagID: String) async {
        guard tagID != selectedFuturesSportID else { return }
        selectedFuturesSportID = tagID
        await loadFutures()
    }

    /// Fetches the selected Futures sport's markets, highest volume first.
    private func loadFutures() async {
        guard let tagID = selectedFuturesSportID else { futuresEvents = []; return }
        futuresEvents = (try? await fetchEvents.execute(tagID: tagID, sort: .volume24h, status: .active))?.items ?? []
    }

    /// Fetches up to `pages` pages of the general sports feed (each page is small — the API
    /// pages at a handful of events — so the highest-volume-only first page rarely surfaces
    /// more than one or two leagues). Stops early once a page comes back empty or without a
    /// next cursor.
    static func fetchSample(_ fetchEvents: FetchEventsUseCase, pages: Int) async -> [Event] {
        var events: [Event] = []
        var cursor: String?
        for _ in 0..<pages {
            guard let page = try? await fetchEvents.execute(cursor: cursor, tagID: sportsTagID, sort: .volume24h, status: .active),
                  !page.items.isEmpty
            else { break }
            events += page.items
            guard let next = page.nextCursor else { break }
            cursor = next
        }
        return events
    }

    /// Matches known (keyword, glyph) pairs against the sample's event tags: the first tag
    /// whose label contains the keyword (case-insensitive) becomes that league's real tag id.
    /// Keeps declaration order; keywords with no match in the sample are dropped.
    static func resolve(_ known: [(label: String, glyph: String)], in events: [Event]) -> [SportsLeague] {
        let tags = events.flatMap(\.tags)
        return known.compactMap { entry in
            let keyword = entry.label.lowercased()
            return tags.first { $0.label.lowercased().contains(keyword) }
                .map { SportsLeague(id: $0.id, title: entry.label, glyph: entry.glyph) }
        }
    }

    /// Buckets events under the first league whose resolved tag id the event carries; events
    /// matching no known league are dropped from the grouped Live feed. Leagues with no live
    /// events are omitted, and the result preserves `leagues` order.
    static func grouped(_ events: [Event], into leagues: [SportsLeague]) -> [(league: SportsLeague, events: [Event])] {
        var buckets: [String: [Event]] = [:]
        for event in events {
            let tagIDs = Set(event.tags.map(\.id))
            guard let match = leagues.first(where: { tagIDs.contains($0.id) }) else { continue }
            buckets[match.id, default: []].append(event)
        }
        return leagues.compactMap { league in
            guard let events = buckets[league.id], !events.isEmpty else { return nil }
            return (league, events)
        }
    }
}

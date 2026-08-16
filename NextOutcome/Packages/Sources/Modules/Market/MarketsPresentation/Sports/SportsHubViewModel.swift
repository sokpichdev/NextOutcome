//
//  SportsHubViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 06/07/2026.
//

import Foundation
import MarketsDomain
import SharedDomain

/// Drives the Sports hub: the Live/Futures mode switch, the league chip row (built from the
/// server sport catalogue, highest volume first), the live feed grouped by league, and the
/// Futures sport picker (NBA/EPL) with its ranked markets.
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

    /// The current load state.
    public private(set) var state: State = .idle
    /// The selected top-level mode.
    public var mode: Mode = .live
    /// The full sport taxonomy from the server, highest volume first. Drives both the nav
    /// row and the All Sports sheet.
    public private(set) var catalogue: [SportGroup] = []
    /// The subset of `catalogue` shown as chips: sports with something open to trade right
    /// now. The sheet still lists the rest, so a dormant sport is reachable, just not
    /// occupying a chip.
    public var navGroups: [SportGroup] { catalogue.filter { $0.activeEventCount > 0 } }
    /// Whether the All Sports sheet is presented.
    public var isShowingAllSports = false
    /// Live/final scores for the Live feed's events, keyed by event id. Absent ids simply
    /// render as not-yet-started.
    public private(set) var results: [String: GameResult] = [:]
    /// The sport selected from the nav row or the sheet, shown in place of the Live feed.
    public var selectedGroup: SportGroup?
    /// The Live tab's sort, chosen via its filter icon.
    public private(set) var liveSort: SportsSort = .volume
    /// The hub-wide odds display format, chosen via the mode bar's Odds Format menu. Applies
    /// to every `GameCard` the hub shows (Live, Futures, and any embedded league content).
    public var oddsFormat: OddsFormat = .price
    /// Whether `GameCard`s across the hub also show spread/total markets.
    public var showSpreadsAndTotals = false
    /// Live events grouped by league, in `catalogue` order; leagues with no live events are omitted.
    public private(set) var liveGroups: [(league: SportsLeague, events: [Event])] = []
    /// The raw Live sample (unsorted, ungrouped), kept so changing `liveSort` doesn't require
    /// a refetch.
    private var sampleEvents: [Event] = []
    /// Sport chips for the Futures picker (NBA/EPL), resolved from the same sample.
    public private(set) var futuresSports: [SportsLeague] = []
    /// The selected Futures sport's tag id.
    public var selectedFuturesSportID: String?
    /// The selected Futures sport's markets (season winner, MVP, etc.), highest volume first.
    public private(set) var futuresEvents: [Event] = []
    /// When the hub's data was last refreshed.
    public private(set) var lastUpdated: Date?

    /// Loads a page of events, optionally by tag (used for the Futures sport picker).
    private let fetchEvents: FetchEventsUseCase
    /// Loads every event under a tag, unpaginated (used for the Live tab's sample, so
    /// league/sport chips can be derived from more than just the highest-volume page).
    private let fetchAllEvents: FetchAllEventsUseCase
    /// Loads the server-side sport taxonomy behind the chip row and All Sports sheet.
    private let fetchSportsCatalogue: FetchSportsCatalogueUseCase
    /// Loads live scores for the events the Live feed is showing.
    private let fetchGameResults: FetchGameResultsUseCase
    /// Injectable clock (defaults to `Date()`), for deterministic tests.
    private let now: @Sendable () -> Date

    /// Creates the view model with its use cases.
    public init(
        fetchEvents: FetchEventsUseCase,
        fetchAllEvents: FetchAllEventsUseCase,
        fetchSportsCatalogue: FetchSportsCatalogueUseCase,
        fetchGameResults: FetchGameResultsUseCase,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fetchEvents = fetchEvents
        self.fetchAllEvents = fetchAllEvents
        self.fetchSportsCatalogue = fetchSportsCatalogue
        self.fetchGameResults = fetchGameResults
        self.now = now
    }

    /// Loads on first appearance only (no-op once loaded/loading).
    public func loadIfNeeded() async {
        if case .idle = state { await load() }
    }

    /// Fetches every event under the general sports tag, loads the server sport catalogue that
    /// drives the chip row and All Sports sheet, groups events into the Live tab's sections
    /// (highest volume first), then kicks off the initial Futures fetch.
    ///
    /// Chips come from Gamma's `/sports` + `/sports/summary` catalogue, not from the sampled
    /// feed's own tags. An earlier version matched five hardcoded keywords as substrings
    /// against event tag labels, which meant a league appeared only when it happened to be in
    /// the sample — Wimbledon vanished for fifty weeks a year, and a new sport never showed at
    /// all. The catalogue also carries the counts and live flags a sampled feed can't.
    public func load() async {
        state = .loading
        async let catalogueTask = try? fetchSportsCatalogue.execute()
        async let eventsTask = try? fetchAllEvents.execute(tagID: Self.sportsTagID, status: .active)

        // Publish the catalogue the moment it lands: the chip row is useful long before the
        // ~25MB event sample finishes, and gating it behind that read as a broken screen for
        // 45+ seconds. Bind before defaulting on both — `await x ?? []` binds as
        // `await (x ?? [])`, which reads the unresolved value.
        let loadedCatalogue = await catalogueTask
        catalogue = loadedCatalogue ?? []

        let loadedEvents = await eventsTask
        let events = loadedEvents ?? []
        guard !events.isEmpty else {
            state = .failed("Couldn't load Sports. Pull to refresh.")
            return
        }
        sampleEvents = events
        futuresSports = catalogue.prefix(8).map {
            SportsLeague(id: $0.navigationTagID, title: $0.name, glyph: $0.glyph)
        }
        if selectedFuturesSportID == nil || !futuresSports.contains(where: { $0.id == selectedFuturesSportID }) {
            selectedFuturesSportID = futuresSports.first?.id
        }
        applyLiveSort()
        state = .loaded
        lastUpdated = now()
        results = (try? await fetchGameResults.execute(eventIDs: Self.initialResultIDs(from: events, now: now()))) ?? [:]
        await loadFutures()
    }

    /// Reloads everything (pull-to-refresh).
    public func refresh() async {
        await load()
    }

    /// Changes the Live tab's sort and regroups the already-fetched sample — no refetch.
    public func setLiveSort(_ sort: SportsSort) {
        guard sort != liveSort else { return }
        liveSort = sort
        applyLiveSort()
    }

    /// Selects a Futures sport chip and reloads its markets, unless already selected.
    public func selectFuturesSport(_ tagID: String) async {
        guard tagID != selectedFuturesSportID else { return }
        selectedFuturesSportID = tagID
        await loadFutures()
    }

    /// Re-sorts `sampleEvents` by `liveSort` and regroups into `liveGroups`.
    private func applyLiveSort() {
        liveGroups = Self.grouped(liveSort.apply(to: sampleEvents), into: catalogue)
    }

    /// Fetches the selected Futures sport's markets, highest volume first.
    private func loadFutures() async {
        guard let tagID = selectedFuturesSportID else { futuresEvents = []; return }
        futuresEvents = (try? await fetchEvents.execute(tagID: tagID, sort: .volume24h, status: .active))?.items ?? []
    }

    /// Events worth an initial score fetch: kickoff within ±24h of `now`, bounded fan-out.
    ///
    /// `fetchGameResults` has no batch endpoint — it issues one HTTP request per id — so
    /// fetching scores for the entire ~500-event sample on every load/refresh fires hundreds
    /// of requests. This narrows to the games whose scores could plausibly be interesting
    /// right now, same approach as `WorldCupHubViewModel.initialResultIDs(windowHours:cap:)`.
    /// - Parameters:
    ///   - events: The candidate events, already volume-sorted (most-traded first).
    ///   - now: The reference time to measure the window from.
    ///   - windowHours: How far around `now` (± hours) a kickoff must fall to qualify.
    ///   - cap: The maximum number of ids to return.
    /// - Returns: Ids of events worth an immediate score fetch, in `events` order.
    static func initialResultIDs(from events: [Event], now: Date, windowHours: Double = 24, cap: Int = 30) -> [String] {
        events
            .filter {
                guard let kickoff = $0.gameStartTime else { return false }
                return abs(kickoff.timeIntervalSince(now)) <= windowHours * 3600
            }
            .prefix(cap)
            .map(\.id)
    }

    /// Buckets events under the first sport carrying one of their tag ids, matching against
    /// every league's `primaryTagID` in the group. Events matching no sport are dropped, and
    /// sports with no live events are omitted; the result preserves catalogue order.
    static func grouped(_ events: [Event], into catalogue: [SportGroup]) -> [(league: SportsLeague, events: [Event])] {
        var tagToGroup: [String: String] = [:]
        for group in catalogue {
            for league in group.leagues where tagToGroup[league.primaryTagID] == nil {
                tagToGroup[league.primaryTagID] = group.id
            }
        }
        var buckets: [String: [Event]] = [:]
        for event in events {
            guard let groupID = event.tags.compactMap({ tagToGroup[$0.id] }).first else { continue }
            buckets[groupID, default: []].append(event)
        }
        return catalogue.compactMap { group in
            guard let events = buckets[group.id], !events.isEmpty else { return nil }
            return (SportsLeague(id: group.id, title: group.name, glyph: group.glyph), events)
        }
    }
}

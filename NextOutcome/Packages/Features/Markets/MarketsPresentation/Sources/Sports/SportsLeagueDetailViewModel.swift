//
//  SportsLeagueDetailViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 06/07/2026.
//

import Foundation
import MarketsDomain

/// Drives a single league's detail screen (e.g. Wimbledon, MLB, UFC): its Games/Props split,
/// a client-side title search, a Volume/Soonest sort, and the standings sheet (the league's
/// highest-volume "champion"-style market, ranked).
@MainActor
@Observable
public final class SportsLeagueDetailViewModel {
    /// The screen's overall load state.
    public enum State: Equatable {
        /// Nothing loaded yet.
        case idle
        /// Loading the league's markets.
        case loading
        /// Markets loaded.
        case loaded
        /// The load failed, with a user-facing message.
        case failed(String)
    }

    /// Which sub-tab is showing: schedulable games, or everything else (futures, props).
    public enum Tab: CaseIterable {
        case games
        case props

        /// The chip label for this tab.
        public var title: String {
            switch self {
            case .games: return "Games"
            case .props: return "Props"
            }
        }
    }

    /// The league this screen shows.
    public let league: SportsLeague
    /// The current load state.
    public private(set) var state: State = .idle
    /// The selected Games/Props tab.
    public var selectedTab: Tab = .games
    /// The list's sort, chosen via the filter icon.
    public private(set) var sort: SportsSort = .volume
    /// Whether the search field is shown.
    public var isSearchActive = false
    /// The current search text.
    public var searchQuery = ""

    /// All of the league's fetched events, unsplit.
    private var events: [Event] = []

    /// Loads every event under the league's tag, unpaginated.
    private let fetchAllEvents: FetchAllEventsUseCase

    /// Creates the view model.
    public init(league: SportsLeague, fetchAllEvents: FetchAllEventsUseCase) {
        self.league = league
        self.fetchAllEvents = fetchAllEvents
    }

    /// Schedulable games: kickoff time + moneyline market.
    private var gameEvents: [Event] { WorldCupEventSplitter.split(events).games }
    /// Everything else: season winners, awards, player props.
    private var propEvents: [Event] { WorldCupEventSplitter.split(events).props }

    /// The selected tab's events, sorted by `sort` and filtered by `searchQuery`.
    public var visibleEvents: [Event] {
        let base = selectedTab == .games ? gameEvents : propEvents
        let sorted = sort.apply(to: base)
        guard !searchQuery.isEmpty else { return sorted }
        return sorted.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
    }

    /// The highest-volume props event (e.g. "Wimbledon Champion"), backing the standings
    /// sheet opened from the trophy icon. `nil` when the league has no props events.
    public var standingsEvent: Event? {
        propEvents.max { $0.volume < $1.volume }
    }

    /// Loads on first appearance only (no-op once loaded/loading).
    public func loadIfNeeded() async {
        if case .idle = state { await load() }
    }

    /// Fetches the league's markets.
    public func load() async {
        state = .loading
        let fetched = (try? await fetchAllEvents.execute(tagID: league.id, status: .active)) ?? []
        guard !fetched.isEmpty else {
            state = .failed("Couldn't load \(league.title). Pull to refresh.")
            return
        }
        events = fetched
        state = .loaded
    }

    /// Reloads (pull-to-refresh).
    public func refresh() async {
        await load()
    }

    /// Changes the list's sort.
    public func setSort(_ sort: SportsSort) {
        self.sort = sort
    }
}

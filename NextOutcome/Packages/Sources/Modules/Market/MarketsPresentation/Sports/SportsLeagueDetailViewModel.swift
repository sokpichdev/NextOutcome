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

    /// The league's games, accumulated across pages.
    private var games: [Event] = []
    /// The league's non-game markets, loaded only once the Props tab is opened.
    public private(set) var propEvents: [Event] = []
    /// Whether the props fetch has already run, so opening the tab twice fetches once.
    private var hasLoadedProps = false
    /// The keyset cursor for the next page of games, `nil` once exhausted.
    private var nextCursor: String?
    /// Whether another page of games exists.
    public var hasMore: Bool { nextCursor != nil }

    /// Loads every event under the league's tag, unpaginated — the Props tab only.
    private let fetchAllEvents: FetchAllEventsUseCase
    /// Loads the league's games, paged and already scoped to real fixtures.
    private let fetchSportsGames: FetchSportsGamesUseCase
    /// Injectable clock, so date section titles are testable.
    private let now: @Sendable () -> Date

    /// Creates the view model.
    public init(
        league: SportsLeague,
        fetchAllEvents: FetchAllEventsUseCase,
        fetchSportsGames: FetchSportsGamesUseCase,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.league = league
        self.fetchAllEvents = fetchAllEvents
        self.fetchSportsGames = fetchSportsGames
        self.now = now
    }

    /// The league's games as dated sections — in play first, then nearest kickoff onward.
    ///
    /// The same sectioner the hub's Live feed uses, so a sport picked from a chip reads the
    /// same way as the feed it was picked from.
    public var gameSections: [SportsFeedSection] {
        let base = searchQuery.isEmpty
            ? games
            : games.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
        return SportsFeedSectioner.sections(for: base, results: [:], now: now())
    }

    /// The Props tab's events, sorted by `sort` and filtered by `searchQuery`. Games are
    /// sectioned by date instead, so `sort` no longer applies to them.
    public var visibleEvents: [Event] {
        let sorted = sort.apply(to: propEvents)
        guard !searchQuery.isEmpty else { return sorted }
        return sorted.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
    }

    /// The highest-volume props event (e.g. "Wimbledon Champion"), backing the standings
    /// sheet opened from the trophy icon. `nil` until the Props tab has been opened.
    public var standingsEvent: Event? {
        propEvents.max { $0.volume < $1.volume }
    }

    /// Loads on first appearance only (no-op once loaded/loading).
    public func loadIfNeeded() async {
        if case .idle = state { await load() }
    }

    /// Fetches the league's games: in-play and the first page of upcoming, concurrently.
    ///
    /// Props are deliberately not fetched here — that call is unpaginated and pulls up to 500
    /// events, and the common path is looking at games.
    public func load() async {
        state = .loading
        nextCursor = nil
        async let inPlayTask = try? fetchSportsGames.execute(
            live: true, startingAfter: nil, cursor: nil, leagueTagID: league.id
        )
        async let pageTask = try? fetchSportsGames.execute(
            live: false, startingAfter: now(), cursor: nil, leagueTagID: league.id
        )
        let inPlay = await inPlayTask
        let page = await pageTask
        let fetched = (inPlay?.items ?? []) + (page?.items ?? [])
        guard !fetched.isEmpty else {
            state = .failed("Couldn't load \(league.title). Pull to refresh.")
            return
        }
        nextCursor = page?.nextCursor
        games = fetched
        state = .loaded
    }

    /// Fetches the league's non-game markets the first time the Props tab is opened.
    public func loadPropsIfNeeded() async {
        guard !hasLoadedProps else { return }
        hasLoadedProps = true
        let fetched = (try? await fetchAllEvents.execute(tagID: league.id, status: .active)) ?? []
        propEvents = WorldCupEventSplitter.split(fetched).props
    }

    /// Fetches the next page of upcoming games.
    public func loadMore() async {
        guard hasMore else { return }
        guard let page = try? await fetchSportsGames.execute(
            live: false, startingAfter: now(), cursor: nextCursor, leagueTagID: league.id
        ) else { return }
        nextCursor = page.nextCursor
        games += page.items
    }

    /// Reloads (pull-to-refresh). Props reload lazily too, on next open.
    public func refresh() async {
        hasLoadedProps = false
        propEvents = []
        await load()
    }

    /// Changes the list's sort.
    public func setSort(_ sort: SportsSort) {
        self.sort = sort
    }
}

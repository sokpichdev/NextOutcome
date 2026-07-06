//
//  SportsLeagueDetailViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 06/07/2026.
//

import Foundation
import MarketsDomain

/// Drives a single league's detail screen (e.g. Wimbledon, MLB, UFC): its full market list
/// plus a client-side title search.
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

    /// The league this screen shows.
    public let league: SportsLeague
    /// The current load state.
    public private(set) var state: State = .idle
    /// The league's markets, highest volume first.
    public private(set) var events: [Event] = []
    /// Whether the search field is shown.
    public var isSearchActive = false
    /// The current search text.
    public var searchQuery = ""

    /// Loads a page of events by tag.
    private let fetchEvents: FetchEventsUseCase

    /// Creates the view model.
    public init(league: SportsLeague, fetchEvents: FetchEventsUseCase) {
        self.league = league
        self.fetchEvents = fetchEvents
    }

    /// `events` filtered by `searchQuery` (title match, case-insensitive) when non-empty.
    public var visibleEvents: [Event] {
        guard !searchQuery.isEmpty else { return events }
        return events.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
    }

    /// Loads on first appearance only (no-op once loaded/loading).
    public func loadIfNeeded() async {
        if case .idle = state { await load() }
    }

    /// Fetches the league's markets.
    public func load() async {
        state = .loading
        guard let page = try? await fetchEvents.execute(tagID: league.id, sort: .volume24h, status: .active),
              !page.items.isEmpty
        else {
            state = .failed("Couldn't load \(league.title). Pull to refresh.")
            return
        }
        events = page.items
        state = .loaded
    }

    /// Reloads (pull-to-refresh).
    public func refresh() async {
        await load()
    }
}

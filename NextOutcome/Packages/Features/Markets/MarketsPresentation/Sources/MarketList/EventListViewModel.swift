//
//  EventListViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import MarketsDomain
import SharedDomain
import DesignSystem

/// Drives the main markets feed: loads a paginated list of events, exposes category and
/// trending-chip filters, sort/status options, and a client-side "hide sports" toggle.
@MainActor
@Observable
public final class EventListViewModel {
    /// What the feed is currently showing.
    public enum State {
        /// Nothing loaded yet.
        case idle
        /// Loading the first page.
        case loading
        /// Loaded events.
        case loaded([Event])
        /// No events for the current filters.
        case empty
        /// The load failed, with a user-facing message.
        case failed(String)
    }

    /// The current feed state.
    public private(set) var state: State = .idle
    /// Whether a "load more" page fetch is in flight.
    public private(set) var isLoadingMore = false

    /// Category filter chips. `selectedTagID == nil` means "All".
    public private(set) var tags: [Tag] = []
    public private(set) var selectedTagID: String?

    /// Trending sub-filter chips, derived from the tags of the unfiltered feed. Shown for
    /// categories in `categoriesWithSubChips` (Trending, Politics — e.g. Politics's
    /// "All/Trump/Trump Daily/Midterms" row). `selectedTrendingTagID == nil` means "All".
    public private(set) var trendingChips: [Tag] = []
    public private(set) var selectedTrendingTagID: String?
    private var currentCategory: HubTab = .trending
    /// Categories that show the sub-filter chip row (derived from the loaded events' tags).
    private static let categoriesWithSubChips: Set<HubTab> = [.trending, .politics]

    /// Whether the sub-filter chip row has anything to show. This row is always visible
    /// (non-collapsible) once populated — the collapsible control is the advanced filter row
    /// instead (see `filterRowVisible`).
    public var showsTrendingChips: Bool { Self.categoriesWithSubChips.contains(currentCategory) && !trendingChips.isEmpty }

    /// The tag actually sent to the API: the trending chip when one is active, else the
    /// category tag. Pagination reads the same value, so `loadMore` follows the chip filter.
    private var effectiveTagID: String? { selectedTrendingTagID ?? selectedTagID }

    /// The sort options offered in the secondary filter row. Which subset is offered
    /// depends on `status` — see `options(for:)`.
    public enum MarketSort: String, CaseIterable {
        case volume24h, volume1wk, volume1mo, volumeTotal, liquidity, newest, endingSoon, competitive, closedTime
        /// The menu label for this sort.
        public var title: String {
            switch self {
            case .volume24h:   return "24hr Volume"
            case .volume1wk:   return "Weekly Volume"
            case .volume1mo:   return "Monthly Volume"
            case .volumeTotal: return "Total Volume"
            case .liquidity:   return "Liquidity"
            case .newest:      return "Newest"
            case .endingSoon:  return "Ending Soon"
            case .competitive: return "Competitive"
            case .closedTime:  return "Closed Time"
            }
        }

        /// The sort options to offer for a given status: resolved events sort by close
        /// time or total volume; active/all events get the full live-market sort set.
        public static func options(for status: MarketStatus) -> [MarketSort] {
            switch status {
            case .resolved: return [.closedTime, .volumeTotal]
            case .active, .all: return [.volume24h, .volumeTotal, .liquidity, .newest, .endingSoon, .competitive]
            }
        }
    }

    /// The status filter offered in the secondary filter row.
    public enum MarketStatus: String, CaseIterable {
        case active, resolved, all
        /// The menu label for this status.
        public var title: String {
            switch self {
            case .active:   return "Active"
            case .resolved: return "Resolved"
            case .all:      return "All"
            }
        }
    }

    /// The "created within" time-window filter offered in the secondary filter row.
    public enum MarketPeriod: String, CaseIterable {
        case daily, weekly, monthly, all
        /// The menu label for this period.
        public var title: String {
            switch self {
            case .daily:   return "Daily"
            case .weekly:  return "Weekly"
            case .monthly: return "Monthly"
            case .all:     return "All"
            }
        }
    }

    /// The active sort order.
    public private(set) var sort: MarketSort = .volume24h
    /// The active status filter.
    public private(set) var status: MarketStatus = .active
    /// The active "created within" period filter.
    public private(set) var period: MarketPeriod = .all
    /// The current search query (client-side title filter over `visibleEvents`).
    public var searchQuery: String = ""
    /// Whether the collapsible advanced-filter row (sort/status/period/hide toggles) is shown.
    public private(set) var filterRowVisible: Bool = false
    /// Toggles visibility of the collapsible advanced-filter row.
    public func toggleFilterRowVisible() { filterRowVisible.toggle() }
    /// Whether sports events are hidden client-side.
    public private(set) var hideSports: Bool = false
    /// Whether crypto events are hidden client-side.
    public private(set) var hideCrypto: Bool = false
    /// Whether earnings events are hidden client-side.
    public private(set) var hideEarnings: Bool = false

    /// Server-side search results for the current `searchQuery`, or `nil` when no search
    /// has completed yet (before the debounce fires, or while the query is empty).
    private var searchResults: [Event]?

    /// Whether the feed is currently in search mode (non-empty query).
    public var isSearchActive: Bool { !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// The events to show: server-side search results while searching, else the loaded
    /// feed page — with the hide-sports/crypto/earnings client filters applied either way.
    public var visibleEvents: [Event] {
        let source: [Event]
        if isSearchActive {
            source = searchResults ?? []
        } else {
            guard case .loaded(let events) = state else { return [] }
            source = events
        }
        return source.filter { event in
            if hideSports && HomeCardKind.isSports(event) { return false }
            if hideCrypto && HomeCardKind.isCrypto(event) { return false }
            if hideEarnings && HomeCardKind.isEarnings(event) { return false }
            return true
        }
    }

    /// Whether a search request is currently in flight.
    public private(set) var isSearching = false

    /// Runs (or clears) the server-side search for the current `searchQuery`. Debounced by
    /// the caller (the view fires this from a `.task(id: searchQuery)` after a short delay,
    /// which SwiftUI cancels and restarts on every keystroke).
    public func performSearch() async {
        guard isSearchActive else { searchResults = nil; return }
        isSearching = true
        defer { isSearching = false }
        searchResults = (try? await searchEvents.execute(query: searchQuery)) ?? []
    }

    /// Apply a category rail selection. Idempotent: re-applying the current category (e.g.
    /// when the list view remounts after the World Cup hub was shown) does not refetch
    /// unless the VM has never loaded.
    public func apply(category: HubTab) async {
        let isInitial: Bool = { if case .idle = state { return true } else { return false } }()
        guard category != currentCategory || isInitial else { return }
        currentCategory = category

        let previousEffective = effectiveTagID
        if category != .trending { selectedTrendingTagID = nil }
        selectedTagID = category.tagID

        if isInitial || effectiveTagID != previousEffective {
            nextCursor = nil
            await load()
        }
    }

    /// Select a trending sub-filter chip (nil = "All") and reload from the top.
    public func selectTrendingChip(tagID: String?) async {
        guard Self.categoriesWithSubChips.contains(currentCategory), tagID != selectedTrendingTagID else { return }
        selectedTrendingTagID = tagID
        nextCursor = nil
        await load()
    }

    /// Changes the sort order and reloads from the top.
    public func setSort(_ newSort: MarketSort) async {
        guard newSort != sort else { return }
        sort = newSort
        nextCursor = nil
        await load()
    }

    /// Changes the status filter and reloads from the top. Clamps `sort` into the option
    /// set valid for the new status (e.g. switching to Resolved falls back to Closed Time).
    public func setStatus(_ newStatus: MarketStatus) async {
        guard newStatus != status else { return }
        status = newStatus
        let validSorts = MarketSort.options(for: newStatus)
        if !validSorts.contains(sort) { sort = validSorts[0] }
        nextCursor = nil
        await load()
    }

    /// Changes the "created within" period filter and reloads from the top.
    public func setPeriod(_ newPeriod: MarketPeriod) async {
        guard newPeriod != period else { return }
        period = newPeriod
        nextCursor = nil
        await load()
    }

    /// Resets sort/status/period/hide filters and search query to their defaults and reloads.
    public func clearFilters() async {
        sort = .volume24h
        status = .active
        period = .all
        hideSports = false
        hideCrypto = false
        hideEarnings = false
        searchQuery = ""
        nextCursor = nil
        await load()
    }

    /// Toggles the client-side hide-sports filter (no refetch — `visibleEvents` re-filters).
    public func toggleHideSports() { hideSports.toggle() }
    /// Toggles the client-side hide-crypto filter (no refetch — `visibleEvents` re-filters).
    public func toggleHideCrypto() { hideCrypto.toggle() }
    /// Toggles the client-side hide-earnings filter (no refetch — `visibleEvents` re-filters).
    public func toggleHideEarnings() { hideEarnings.toggle() }

    /// Whether any client-side hide filter is active (used to decide whether `loadMore`
    /// should keep fetching extra pages to compensate for filtered-out items).
    private var anyHideFilterActive: Bool { hideSports || hideCrypto || hideEarnings }

    /// The cursor for the next page, or `nil` at the end.
    private var nextCursor: String?
    /// Whether another page is available.
    public var hasMore: Bool { nextCursor != nil }

    /// Use case that fetches event pages.
    private let fetchEvents: FetchEventsUseCase
    /// Use case that fetches the filter tags.
    private let fetchTags: FetchTagsUseCase
    /// Use case that runs the server-side event search.
    private let searchEvents: SearchEventsUseCase

    /// Creates the view model.
    /// - Parameters:
    ///   - fetchEvents: Loads event pages.
    ///   - fetchTags: Loads the category filter tags.
    ///   - searchEvents: Runs the server-side event search. Defaults to a stub in DEBUG for
    ///     call sites that don't wire search (e.g. existing tests).
    public init(fetchEvents: FetchEventsUseCase, fetchTags: FetchTagsUseCase, searchEvents: SearchEventsUseCase) {
        self.fetchEvents = fetchEvents
        self.fetchTags = fetchTags
        self.searchEvents = searchEvents
    }

    /// The domain sort corresponding to the selected `MarketSort`.
    private var domainSort: EventSort {
        switch sort {
        case .volume24h:   return .volume24h
        case .volume1wk:   return .volume1wk
        case .volume1mo:   return .volume1mo
        case .volumeTotal: return .volumeTotal
        case .liquidity:   return .liquidity
        case .newest:      return .newest
        case .endingSoon:  return .endingSoon
        case .competitive: return .competitive
        case .closedTime:  return .closedTime
        }
    }

    /// The domain status corresponding to the selected `MarketStatus`.
    private var domainStatus: EventStatus {
        switch status {
        case .active:   return .active
        case .resolved: return .resolved
        case .all:      return .all
        }
    }

    /// The domain period corresponding to the selected `MarketPeriod`.
    private var domainPeriod: EventPeriod {
        switch period {
        case .daily:   return .daily
        case .weekly:  return .weekly
        case .monthly: return .monthly
        case .all:     return .all
        }
    }

    /// Loads the first page for the current filters, and (on the unfiltered trending feed)
    /// derives the trending sub-filter chips.
    public func load() async {
        state = .loading
        if tags.isEmpty { await loadTags() }
        do {
            let page = try await fetchEvents.execute(tagID: effectiveTagID, sort: domainSort, status: domainStatus, period: domainPeriod)
            nextCursor = page.nextCursor
            state = page.items.isEmpty ? .empty : .loaded(page.items)
            // Chips come only from the *unfiltered* feed so the row doesn't reshuffle while
            // the user filters with it.
            if Self.categoriesWithSubChips.contains(currentCategory) && selectedTrendingTagID == nil && !page.items.isEmpty {
                trendingChips = TrendingChipDeriver.chips(from: page.items)
            }
        } catch {
            state = .failed("Couldn't load markets. pull to refresh.")
        }
    }

    /// Reloads from the first page (pull-to-refresh).
    public func refresh() async {
        nextCursor = nil
        await load()
    }

    /// Select a category chip (nil = All) and reload from the top.
    public func select(tagID: String?) async {
        guard tagID != selectedTagID else { return }
        selectedTagID = tagID
        nextCursor = nil
        await load()
    }

    /// Appends the next page when the user scrolls near the end. When hide-sports is on and a
    /// page yields no visible items, it keeps fetching (bounded to 5 extra pages) so the
    /// feed can still advance. Errors are non-fatal — the existing list stays visible.
    public func loadMore() async {
        guard case .loaded(let current) = state, let cursor = nextCursor, !isLoadingMore else {
            return
        }

        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await fetchEvents.execute(cursor: cursor, tagID: effectiveTagID, sort: domainSort, status: domainStatus, period: domainPeriod)
            nextCursor = page.nextCursor
            state = .loaded(current + page.items)

            // If a hide filter filtered out all new items and more pages exist, keep fetching
            // (bounded to 5 extra fetches) so the visible feed can advance.
            if anyHideFilterActive {
                let before = visibleEvents.count
                var extra = 0
                while nextCursor != nil && visibleEvents.count == before && extra < 5 {
                    guard case .loaded(let all) = state, let nc = nextCursor else { break }
                    let next = try await fetchEvents.execute(cursor: nc, tagID: effectiveTagID, sort: domainSort, status: domainStatus, period: domainPeriod)
                    nextCursor = next.nextCursor
                    state = .loaded(all + next.items)
                    extra += 1
                }
            }
        } catch {
            // non-fatal: keep the list we already have; user can scroll again to retry.
        }
    }

    /// Loads the category filter tags. Best-effort: a failure just hides the filter row.
    private func loadTags() async {
        // Tags are a non-critical enhancement — a failure just hides the filter row.
        tags = (try? await fetchTags.execute()) ?? []
    }

    /// Test seam: build a VM pre-seeded into `.loaded` without a use case round-trip.
    #if DEBUG
    static func makeForTesting(events: [Event]) -> EventListViewModel {
        let vm = EventListViewModel(
            fetchEvents: FetchEventsUseCase.stub,
            fetchTags: FetchTagsUseCase.stub,
            searchEvents: SearchEventsUseCase.stub
        )
        vm.state = .loaded(events)
        return vm
    }

    /// Seed the VM with explicit state for unit testing loadMore() pagination scenarios.
    func seedForTesting(state: State, nextCursor: String?, hideSports: Bool = false) {
        self.state = state
        self.nextCursor = nextCursor
        if hideSports { self.hideSports = true }
    }
    #endif
}

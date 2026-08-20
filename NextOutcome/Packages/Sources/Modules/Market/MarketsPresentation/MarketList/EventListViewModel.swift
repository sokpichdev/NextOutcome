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

    /// The tag id of the selected category, or `nil` for the unfiltered feed.
    public private(set) var selectedTagID: String?

    /// The selected category's sub-topic chips — Gamma's own carousel row for that category
    /// (e.g. Politics's "Trump / Trump Daily / Midterms"), in the server's rank order.
    /// `selectedSubTopicTagID == nil` means "All", the synthetic leading chip.
    public private(set) var subTopicChips: [Tag] = []
    public private(set) var selectedSubTopicTagID: String?
    private var currentCategory: HubTab = .all

    /// Whether the sub-topic chip row has anything to show. Purely data-driven: several
    /// categories genuinely have no sub-topics and simply don't render the row. It's always
    /// visible (non-collapsible) once populated — the collapsible control is the advanced
    /// filter row instead (see `filterRowVisible`).
    public var showsSubTopicChips: Bool { !subTopicChips.isEmpty }

    /// The tag actually sent to the API: the sub-topic chip when one is active, else the
    /// category tag. Pagination reads the same value, so `loadMore` follows the chip filter.
    private var effectiveTagID: String? { selectedSubTopicTagID ?? selectedTagID }

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

    /// Polymarket's curated featured list, in editorial rank order. Loaded best-effort —
    /// a failure leaves this empty and the feed renders exactly as it did before.
    public private(set) var featuredEvents: [Event] = []

    /// How many curated rows to pin above the feed.
    ///
    /// Polymarket's web client splices several pin types (featured markets, a sports strip,
    /// the BTC 5m slot) into the first few slots; we implement the featured-markets pin only,
    /// and three matches the number of curated cards the web shows before its feed proper
    /// begins. Pinning all twenty would bury the volume feed entirely.
    private static let pinnedFeaturedCount = 3

    /// Whether the curated rows apply right now.
    ///
    /// Only on the default feed — no category, no sub-topic, no search, default sort/status.
    /// Mirrors the web's `visibilityRules: [{ type: "default-feed" }]`: a curated ranking is
    /// meaningless once the user has asked for something specific.
    private var showsFeatured: Bool {
        !isSearchActive
            && selectedTagID == nil
            && selectedSubTopicTagID == nil
            && sort == .volume24h
            && status == .active
            && period == .all
    }

    /// Whether an event survives the hide-sports/crypto/earnings toggles.
    private func passesHideFilters(_ event: Event) -> Bool {
        if hideSports && HomeCardKind.isSports(event) { return false }
        if hideCrypto && HomeCardKind.isCrypto(event) { return false }
        if hideEarnings && HomeCardKind.isEarnings(event) { return false }
        return true
    }

    /// The events to show: server-side search results while searching, else the loaded
    /// feed page — with the hide-sports/crypto/earnings client filters applied either way,
    /// and the curated featured rows pinned on top of the default feed.
    ///
    /// Pinned rows are removed from the body of the feed so a featured event can't appear
    /// twice, matching how the web de-duplicates its pins against the main list.
    ///
    /// Signposted: this is uncached, so `ForEach` re-runs the whole pipeline on every body
    /// evaluation. The interval's *count* under a scroll is the number that matters — see
    /// `Perf.visibleEventsHome`.
    public var visibleEvents: [Event] {
        let signpost = Perf.renderPath.beginInterval(Perf.visibleEventsHome)
        defer { Perf.renderPath.endInterval(Perf.visibleEventsHome, signpost) }

        let source: [Event]
        if isSearchActive {
            source = searchResults ?? []
        } else {
            guard case .loaded(let events) = state else { return [] }
            source = events
        }
        let filtered = source.filter(passesHideFilters)
        guard showsFeatured else { return filtered }
        let pinned = featuredEvents.filter(passesHideFilters).prefix(Self.pinnedFeaturedCount)
        guard !pinned.isEmpty else { return filtered }
        let pinnedIDs = Set(pinned.map(\.id))
        return Array(pinned) + filtered.filter { !pinnedIDs.contains($0.id) }
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
        // A sub-topic belongs to the category it came from, so switching category always
        // drops it — otherwise Politics's "Midterms" would survive into Tech.
        selectedSubTopicTagID = nil
        selectedTagID = category.tagID

        await loadSubTopicChips(for: category)

        if isInitial || effectiveTagID != previousEffective {
            nextCursor = nil
            await load()
        }
    }

    /// Loads the sub-topic carousel for `category`. Best-effort: a failure just leaves the row
    /// hidden. Cheap to call repeatedly — the repository caches each row by slug.
    private func loadSubTopicChips(for category: HubTab) async {
        subTopicChips = (try? await fetchRelatedTags.execute(slug: category.id)) ?? []
    }

    /// Select a sub-topic chip (nil = "All") and reload from the top.
    public func selectSubTopicChip(tagID: String?) async {
        guard tagID != selectedSubTopicTagID else { return }
        selectedSubTopicTagID = tagID
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
    /// Use case that fetches a category's sub-topic chip row.
    private let fetchRelatedTags: FetchRelatedTagsUseCase
    /// Use case that runs the server-side event search.
    private let searchEvents: SearchEventsUseCase
    /// Use case that loads the curated featured list pinned above the default feed.
    private let fetchFeaturedEvents: FetchFeaturedEventsUseCase

    /// Creates the view model.
    /// - Parameters:
    ///   - fetchEvents: Loads event pages.
    ///   - fetchRelatedTags: Loads the selected category's sub-topic chips.
    ///   - searchEvents: Runs the server-side event search. Defaults to a stub in DEBUG for
    ///     call sites that don't wire search (e.g. existing tests).
    ///   - fetchFeaturedEvents: Loads the curated featured rows.
    public init(
        fetchEvents: FetchEventsUseCase,
        fetchRelatedTags: FetchRelatedTagsUseCase,
        searchEvents: SearchEventsUseCase,
        fetchFeaturedEvents: FetchFeaturedEventsUseCase
    ) {
        self.fetchEvents = fetchEvents
        self.fetchRelatedTags = fetchRelatedTags
        self.searchEvents = searchEvents
        self.fetchFeaturedEvents = fetchFeaturedEvents
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

    /// Loads the first page for the current filters, and the curated rows alongside it.
    public func load() async {
        state = .loading
        async let featured = loadFeatured()
        do {
            let page = try await fetchEvents.execute(tagID: effectiveTagID, sort: domainSort, status: domainStatus, period: domainPeriod)
            nextCursor = page.nextCursor
            state = page.items.isEmpty ? .empty : .loaded(page.items)
        } catch {
            state = .failed("Couldn't load markets. pull to refresh.")
        }
        await featured
    }

    /// Loads the curated featured rows, best-effort.
    ///
    /// Deliberately never surfaces an error: the featured row is an enhancement, and a
    /// failure here must not take down a feed that loaded fine. Skipped entirely when the
    /// user has filtered or searched, since the rows wouldn't be shown anyway.
    private func loadFeatured() async {
        guard showsFeatured else { return }
        featuredEvents = (try? await fetchFeaturedEvents.execute()) ?? []
    }

    /// Reloads from the first page (pull-to-refresh).
    public func refresh() async {
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

    /// Test seam: build a VM pre-seeded into `.loaded` without a use case round-trip.
    #if DEBUG
    static func makeForTesting(events: [Event]) -> EventListViewModel {
        let vm = EventListViewModel(
            fetchEvents: FetchEventsUseCase.stub,
            fetchRelatedTags: FetchRelatedTagsUseCase.stub,
            searchEvents: SearchEventsUseCase.stub,
            fetchFeaturedEvents: FetchFeaturedEventsUseCase.stub
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

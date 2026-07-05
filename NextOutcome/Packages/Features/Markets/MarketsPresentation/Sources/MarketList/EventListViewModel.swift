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

    /// Trending sub-filter chips, derived from the tags of the unfiltered trending feed.
    /// `selectedTrendingTagID == nil` means "All". Orthogonal to `selectedTagID`: the chip
    /// only exists while the rail is on Trending (which itself applies no tag filter).
    public private(set) var trendingChips: [Tag] = []
    public private(set) var selectedTrendingTagID: String?
    private var currentCategory: ShellCategory = .trending

    public var showsTrendingChips: Bool { currentCategory == .trending && !trendingChips.isEmpty }

    /// The tag actually sent to the API: the trending chip when one is active, else the
    /// category tag. Pagination reads the same value, so `loadMore` follows the chip filter.
    private var effectiveTagID: String? { selectedTrendingTagID ?? selectedTagID }

    /// The sort options offered in the secondary filter row.
    public enum MarketSort: String, CaseIterable {
        case volume24h, liquidity, newest, endingSoon, competitive
        /// The menu label for this sort.
        public var title: String {
            switch self {
            case .volume24h:   return "24hr Volume"
            case .liquidity:   return "Liquidity"
            case .newest:      return "Newest"
            case .endingSoon:  return "Ending Soon"
            case .competitive: return "Competitive"
            }
        }
    }

    /// The status filter offered in the secondary filter row.
    public enum MarketStatus: String, CaseIterable {
        case active, all
        /// The menu label for this status.
        public var title: String { self == .active ? "Active" : "All" }
    }

    /// The active sort order.
    public private(set) var sort: MarketSort = .volume24h
    /// The active status filter.
    public private(set) var status: MarketStatus = .active
    /// Whether sports events are hidden client-side.
    public private(set) var hideSports: Bool = false

    /// Loaded events with the hide-sports client filter applied.
    public var visibleEvents: [Event] {
        guard case .loaded(let events) = state else { return [] }
        return hideSports ? events.filter { !HomeCardKind.isSports($0) } : events
    }

    /// Stable Gamma tag ids for the top-level category rail. `nil` = no filter (Trending).
    ///
    /// The app fetches the carousel-tags endpoint (`/tags?is_carousel=true`) for the filter
    /// row, but that returns almost nothing, so resolving a category against that list left
    /// every chip mapping to `nil` and silently no-op'ing. These ids are resolved directly and
    /// were verified against `gamma /tags/slug/<slug>` (world-cup=519, breaking-news=198,
    /// politics=2, sports=1).
    public static func tagID(for category: ShellCategory) -> String? {
        switch category {
        case .trending: return nil
        case .worldCup: return "519"
        case .breaking: return "198"
        case .politics: return "2"
        case .sports:   return "1"
        }
    }

    /// Map a shell category to a Gamma tag id using a loaded tag list (slug/label match).
    /// Retained as a fallback for when a live tag list is available; the rail resolves via
    /// the stable-id overload above.
    public static func tagID(for category: ShellCategory, in tags: [Tag]) -> String? {
        let wanted: Set<String>
        switch category {
        case .trending: return nil
        case .worldCup: wanted = ["world cup", "soccer", "football"]
        case .breaking: wanted = ["breaking", "news"]
        case .politics: wanted = ["politics"]
        case .sports:   wanted = ["sports"]
        }
        return tags.first { wanted.contains($0.slug.lowercased()) || wanted.contains($0.label.lowercased()) }?.id
    }

    /// Apply a category rail selection. Idempotent: re-applying the current category (e.g.
    /// when the list view remounts after the World Cup hub was shown) does not refetch
    /// unless the VM has never loaded.
    public func apply(category: ShellCategory) async {
        let isInitial: Bool = { if case .idle = state { return true } else { return false } }()
        guard category != currentCategory || isInitial else { return }
        currentCategory = category

        let previousEffective = effectiveTagID
        if category != .trending { selectedTrendingTagID = nil }
        selectedTagID = Self.tagID(for: category)

        if isInitial || effectiveTagID != previousEffective {
            nextCursor = nil
            await load()
        }
    }

    /// Select a trending sub-filter chip (nil = "All") and reload from the top.
    public func selectTrendingChip(tagID: String?) async {
        guard currentCategory == .trending, tagID != selectedTrendingTagID else { return }
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

    /// Changes the status filter and reloads from the top.
    public func setStatus(_ newStatus: MarketStatus) async {
        guard newStatus != status else { return }
        status = newStatus
        nextCursor = nil
        await load()
    }

    /// Toggles the client-side hide-sports filter (no refetch — `visibleEvents` re-filters).
    public func toggleHideSports() { hideSports.toggle() }

    /// The cursor for the next page, or `nil` at the end.
    private var nextCursor: String?
    /// Whether another page is available.
    public var hasMore: Bool { nextCursor != nil }

    /// Use case that fetches event pages.
    private let fetchEvents: FetchEventsUseCase
    /// Use case that fetches the filter tags.
    private let fetchTags: FetchTagsUseCase

    /// Creates the view model.
    /// - Parameters:
    ///   - fetchEvents: Loads event pages.
    ///   - fetchTags: Loads the category filter tags.
    public init(fetchEvents: FetchEventsUseCase, fetchTags: FetchTagsUseCase) {
        self.fetchEvents = fetchEvents
        self.fetchTags = fetchTags
    }

    /// The domain sort corresponding to the selected `MarketSort`.
    private var domainSort: EventSort {
        switch sort {
        case .volume24h:   return .volume24h
        case .liquidity:   return .liquidity
        case .newest:      return .newest
        case .endingSoon:  return .endingSoon
        case .competitive: return .competitive
        }
    }

    /// The domain status corresponding to the selected `MarketStatus`.
    private var domainStatus: EventStatus { status == .active ? .active : .all }

    /// Loads the first page for the current filters, and (on the unfiltered trending feed)
    /// derives the trending sub-filter chips.
    public func load() async {
        state = .loading
        if tags.isEmpty { await loadTags() }
        do {
            let page = try await fetchEvents.execute(tagID: effectiveTagID, sort: domainSort, status: domainStatus)
            nextCursor = page.nextCursor
            state = page.items.isEmpty ? .empty : .loaded(page.items)
            // Chips come only from the *unfiltered* trending feed so the row doesn't
            // reshuffle while the user filters with it.
            if currentCategory == .trending && selectedTrendingTagID == nil && !page.items.isEmpty {
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
            let page = try await fetchEvents.execute(cursor: cursor, tagID: effectiveTagID, sort: domainSort, status: domainStatus)
            nextCursor = page.nextCursor
            state = .loaded(current + page.items)

            // If hideSports filtered out all new items and more pages exist, keep fetching
            // (bounded to 5 extra fetches) so the visible feed can advance.
            if hideSports {
                let before = visibleEvents.count
                var extra = 0
                while nextCursor != nil && visibleEvents.count == before && extra < 5 {
                    guard case .loaded(let all) = state, let nc = nextCursor else { break }
                    let next = try await fetchEvents.execute(cursor: nc, tagID: effectiveTagID, sort: domainSort, status: domainStatus)
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
            fetchTags: FetchTagsUseCase.stub
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

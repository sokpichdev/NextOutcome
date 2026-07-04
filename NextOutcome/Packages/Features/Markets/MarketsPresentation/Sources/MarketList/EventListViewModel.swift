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

@MainActor
@Observable
public final class EventListViewModel {
    public enum State {
        case idle, loading, loaded([Event]), empty, failed(String)
    }

    public private(set) var state: State = .idle
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

    public enum MarketSort: String, CaseIterable {
        case volume24h, liquidity, newest, endingSoon, competitive
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

    public enum MarketStatus: String, CaseIterable {
        case active, all
        public var title: String { self == .active ? "Active" : "All" }
    }

    public private(set) var sort: MarketSort = .volume24h
    public private(set) var status: MarketStatus = .active
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

    public func setSort(_ newSort: MarketSort) async {
        guard newSort != sort else { return }
        sort = newSort
        nextCursor = nil
        await load()
    }

    public func setStatus(_ newStatus: MarketStatus) async {
        guard newStatus != status else { return }
        status = newStatus
        nextCursor = nil
        await load()
    }

    public func toggleHideSports() { hideSports.toggle() }

    private var nextCursor: String?
    public var hasMore: Bool { nextCursor != nil }

    private let fetchEvents: FetchEventsUseCase
    private let fetchTags: FetchTagsUseCase

    public init(fetchEvents: FetchEventsUseCase, fetchTags: FetchTagsUseCase) {
        self.fetchEvents = fetchEvents
        self.fetchTags = fetchTags
    }

    private var domainSort: EventSort {
        switch sort {
        case .volume24h:   return .volume24h
        case .liquidity:   return .liquidity
        case .newest:      return .newest
        case .endingSoon:  return .endingSoon
        case .competitive: return .competitive
        }
    }

    private var domainStatus: EventStatus { status == .active ? .active : .all }

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

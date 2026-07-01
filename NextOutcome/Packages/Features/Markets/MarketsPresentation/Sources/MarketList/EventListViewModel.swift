//
//  EventListViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import MarketsDomain
import SharedDomain

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

    private var nextCursor: String?
    public var hasMore: Bool { nextCursor != nil }

    private let fetchEvents: FetchEventsUseCase
    private let fetchTags: FetchTagsUseCase

    public init(fetchEvents: FetchEventsUseCase, fetchTags: FetchTagsUseCase) {
        self.fetchEvents = fetchEvents
        self.fetchTags = fetchTags
    }

    public func load() async {
        state = .loading
        if tags.isEmpty { await loadTags() }
        do {
            let page = try await fetchEvents.execute(tagID: selectedTagID)
            nextCursor = page.nextCursor
            state = page.items.isEmpty ? .empty : .loaded(page.items)
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
            let page = try await fetchEvents.execute(cursor: cursor, tagID: selectedTagID)
            nextCursor = page.nextCursor
            state = .loaded(current + page.items)
        } catch {
            // non-fatal: keep the list we already have; user can scroll again to retry.
        }
    }

    private func loadTags() async {
        // Tags are a non-critical enhancement — a failure just hides the filter row.
        tags = (try? await fetchTags.execute()) ?? []
    }
}

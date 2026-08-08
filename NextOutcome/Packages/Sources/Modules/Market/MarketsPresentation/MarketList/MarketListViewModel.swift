//
//  MarketListViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation
import MarketsDomain
import SharedDomain

/// Drives a paginated list of individual markets, with optional text search. (A lighter
/// sibling of `EventListViewModel` used where a flat market list is needed.)
@Observable
public final class MarketListViewModel {
    /// What the list is currently showing.
    public enum State {
        /// Nothing loaded yet.
        case idle
        /// Loading.
        case loading
        /// Loaded markets.
        case loaded([Market])
        /// The load failed.
        case failed(Error)
    }

    /// The current list state.
    public private(set) var state: State = .idle
    /// The cursor for the next page, or `nil` at the end.
    public private(set) var nextCursor: String?
    /// Whether another page is available.
    public var hasMore: Bool { nextCursor != nil }

    /// Use case that fetches market pages.
    private let fetchMarkets: FetchMarketsUseCase
    /// Use case that searches markets.
    private let searchMarkets: SearchMarketsUseCase

    /// Creates the view model.
    /// - Parameters:
    ///   - fetchMarkets: Loads market pages.
    ///   - searchMarkets: Runs market searches.
    public init(fetchMarkets: FetchMarketsUseCase, searchMarkets: SearchMarketsUseCase) {
        self.fetchMarkets = fetchMarkets
        self.searchMarkets = searchMarkets
    }

    /// Loads the first page of markets.
    public func load() async {
        state = .loading
        do {
            let page = try await fetchMarkets.execute()
            nextCursor = page.nextCursor
            state = .loaded(page.items)
        } catch {
            state = .failed(error)
        }
    }
    
    /// Appends the next page of markets.
    public func loadMore() async {
        guard case .loaded(let current) = state, let cursor = nextCursor else { return }
        do {
            let page = try await fetchMarkets.execute(cursor: cursor)
            nextCursor = page.nextCursor
            state = .loaded(current + page.items)
        } catch {
            state = .failed(error)
        }
    }

    /// Searches markets by text, or reloads the full list when the query is empty.
    /// - Parameter query: The search text.
    public func search(query: String) async {
        guard !query.isEmpty else { await load(); return }
        state = .loading
        do {
            let results = try await searchMarkets.execute(query: query)
            state = .loaded(results)
        } catch {
            state = .failed(error)
        }
    }
}

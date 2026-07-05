//
//  SearchViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import MarketsDomain

/// Drives the market search screen: debounces the user's typing, runs the search, and
/// exposes results/empty/error states.
@MainActor
@Observable
public final class SearchViewModel {
    /// What the search screen is currently showing.
    public enum State {
        /// No query yet.
        case idle
        /// A search is running.
        case loading
        /// Matching markets.
        case results([Market])
        /// The query returned nothing.
        case empty
        /// The search failed, with a user-facing message.
        case failed(String)
    }

    /// The current query text.
    public private(set) var query: String = ""
    /// The current search state.
    public private(set) var state: State = .idle

    /// Use case that runs the market search.
    private var searchMarkets: SearchMarketsUseCase
    /// The in-flight debounced search task, cancelled when the query changes.
    private var searchTask: Task<Void, Never>?

    /// Creates the view model.
    /// - Parameter searchMarkets: The search use case.
    public init(searchMarkets: SearchMarketsUseCase) {
        self.searchMarkets = searchMarkets
    }

    /// Handles a query change from the search field: cancels any pending search, resets to
    /// idle on an empty query, and otherwise schedules a debounced search.
    /// - Parameter newValue: The new query text.
    public func queryChanged(_ newValue: String) {
        query = newValue
        searchTask?.cancel()
        
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { state = .idle; return }
        
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 30ms debounce
            guard !Task.isCancelled else { return }
            await self?.performSearch(trimmed)
        }
    }
    
    /// Runs the actual search for a term and updates `state`, ignoring the result if the
    /// task was cancelled by a newer keystroke.
    /// - Parameter term: The trimmed search term.
    private func performSearch(_ term: String) async {
        state = .loading
        do {
            let results = try await searchMarkets.execute(query: term)
            guard !Task.isCancelled else { return }
            state = results.isEmpty ? .empty : .results(results)
        } catch {
            state = .failed("Search failed. Try again.")
        }
    }
}

//
//  SearchViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import MarketsDomain

@MainActor
@Observable
public final class SearchViewModel {
    public enum State {
        case idle,  loading, results([Market]), empty, failed(String)
    }
    
    public private(set) var query: String = ""
    public private(set) var state: State = .idle
    
    private var searchMarkets: SearchMarketsUseCase
    private var searchTask: Task<Void, Never>?
    
    public init(searchMarkets: SearchMarketsUseCase) {
        self.searchMarkets = searchMarkets
    }
    
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

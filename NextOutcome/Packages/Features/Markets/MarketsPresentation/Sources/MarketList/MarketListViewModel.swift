//
//  MarketListViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation
import MarketsDomain
import SharedDomain

@Observable
public final class MarketListViewModel {
    public enum State { case idle, loading, loaded([Market]), failed(Error) }
    
    public private(set) var state: State = .idle
    public private(set) var nextCursor: String?
    public var hasMore: Bool { nextCursor != nil }
    
    private let fetchMarkets: FetchMarketsUseCase
    private let searchMarkets: SearchMarketsUseCase
    
    public init(fetchMarkets: FetchMarketsUseCase, searchMarkets: SearchMarketsUseCase) {
        self.fetchMarkets = fetchMarkets
        self.searchMarkets = searchMarkets
    }
    
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

//
//  ActivityViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import PortfolioDomain

@MainActor
@Observable
public final class ActivityViewModel {
    public enum State {
        case needsAddress
        case loading
        case loaded([Activity])
        case empty
        case failed(String)
    }

    public private(set) var state: State = .needsAddress
    public private(set) var isLoadingMore = false

    private var nextCursor: String?
    public var hasMore: Bool { nextCursor != nil }

    private let fetchActivity: FetchActivityUseCase
    private let addressStore: WatchAddressStore

    public init(fetchActivity: FetchActivityUseCase, addressStore: WatchAddressStore = WatchAddressStore()) {
        self.fetchActivity = fetchActivity
        self.addressStore = addressStore
    }

    public func load() async {
        guard let address = addressStore.address else { state = .needsAddress; return }
        state = .loading
        nextCursor = nil
        do {
            let page = try await fetchActivity.execute(address: address)
            nextCursor = page.nextCursor
            state = page.items.isEmpty ? .empty : .loaded(page.items)
        } catch {
            state = .failed("Couldn't load activity. Pull to refresh.")
        }
    }

    public func refresh() async { await load() }

    public func loadMore() async {
        guard case .loaded(let current) = state,
              let address = addressStore.address,
              let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await fetchActivity.execute(address: address, cursor: cursor)
            nextCursor = page.nextCursor
            state = .loaded(current + page.items)
        } catch {
            // non-fatal; keep what we have
        }
    }
}

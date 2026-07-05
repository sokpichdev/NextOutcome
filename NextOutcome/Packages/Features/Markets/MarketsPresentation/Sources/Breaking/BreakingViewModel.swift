//
//  BreakingViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import Foundation
import MarketsDomain
import SharedDomain

/// Drives the Breaking feed: loads the ranked 24h movers for the selected category pill and
/// exposes them through a `LoadState`. Switching pills re-queries scoped to that tag.
@MainActor
@Observable
public final class BreakingViewModel {
    /// The movers list wrapped in a load state.
    public private(set) var state: LoadState<[Mover]> = .idle
    /// The currently-selected category pill.
    public private(set) var category: BreakingCategory = .all

    /// The use case that fetches the ranked movers.
    private let fetchMovers: FetchMoversUseCase

    /// Discards stale results when pills are switched rapidly: only the most recent load may
    /// write `state`.
    private var loadGeneration = 0

    /// Creates the view model.
    /// - Parameter fetchMovers: The use case that fetches the ranked movers.
    public init(fetchMovers: FetchMoversUseCase) {
        self.fetchMovers = fetchMovers
    }

    /// Loads the movers for the current category. Idempotent on first appearance: re-invoking
    /// while already loaded is a no-op unless a category change requested a reload.
    public func loadIfNeeded() async {
        if case .idle = state { await load() }
    }

    /// Selects a category pill and reloads the movers scoped to it. No-op if unchanged.
    /// - Parameter category: The pill the user tapped.
    public func select(_ category: BreakingCategory) async {
        guard category != self.category else { return }
        self.category = category
        await load()
    }

    /// Reloads the movers for the current category (pull-to-refresh / retry).
    public func reload() async {
        await load()
    }

    /// Fetches and ranks the movers for `category`, keeping the previous list visible while a
    /// category switch is in flight, and ignoring superseded results via `loadGeneration`.
    private func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        if case .loaded = state {
            // keep the current list on screen while the new category loads
        } else {
            state = .loading
        }
        do {
            let movers = try await fetchMovers.execute(tagID: category.tagID)
            guard generation == loadGeneration else { return }
            state = movers.isEmpty ? .empty : .loaded(movers)
        } catch {
            guard generation == loadGeneration else { return }
            state = .failed(message: "Couldn't load breaking movers. Pull to refresh.")
        }
    }
}

//
//  ActivityViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import PortfolioDomain

/// Drives the activity feed: loads the first page for the watched wallet and appends more
/// pages as the user scrolls.
@MainActor
@Observable
public final class ActivityViewModel {
    /// What the activity screen is currently showing.
    public enum State {
        /// No wallet is being watched yet.
        case needsAddress
        /// Loading the first page.
        case loading
        /// Loaded activity rows.
        case loaded([Activity])
        /// The wallet has no activity.
        case empty
        /// The load failed.
        /// - Parameter String: A user-facing error message.
        case failed(String)
    }

    /// The current view state.
    public private(set) var state: State = .needsAddress
    /// Whether a "load more" page fetch is in flight (drives the footer spinner).
    public private(set) var isLoadingMore = false

    /// The cursor for the next page, or `nil` when there are no more pages.
    private var nextCursor: String?
    /// Whether another page is available to load.
    public var hasMore: Bool { nextCursor != nil }

    /// Use case that fetches activity pages.
    private let fetchActivity: FetchActivityUseCase
    /// Supplies the watched wallet address.
    private let addressStore: WatchAddressStore

    /// Creates the view model.
    /// - Parameters:
    ///   - fetchActivity: Loads pages of activity.
    ///   - addressStore: Supplies the watched wallet address.
    public init(fetchActivity: FetchActivityUseCase, addressStore: WatchAddressStore = WatchAddressStore()) {
        self.fetchActivity = fetchActivity
        self.addressStore = addressStore
    }

    /// Loads the first page of activity for the watched wallet (or prompts if none is set).
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

    /// Reloads from the first page (pull-to-refresh).
    public func refresh() async { await load() }

    /// Appends the next page when the user scrolls near the end. Silently ignores errors
    /// (the already-loaded rows stay visible) and guards against concurrent loads.
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

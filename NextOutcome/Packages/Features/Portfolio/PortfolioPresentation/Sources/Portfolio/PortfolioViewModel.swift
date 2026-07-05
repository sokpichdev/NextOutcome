//
//  PortfolioViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import PortfolioDomain

/// Drives the Portfolio tab: prompts for a wallet to watch, then loads that wallet's value,
/// open positions, and closed positions.
///
/// `@MainActor` + `@Observable` so SwiftUI re-renders as `state` changes.
@MainActor
@Observable
public final class PortfolioViewModel {
    /// What the Portfolio tab is currently showing.
    public enum State {
        /// No wallet is being watched yet — show the address prompt.
        case needsAddress
        /// Loading the watched wallet.
        case loading
        /// Loaded a non-empty portfolio.
        case loaded(Portfolio)
        /// The wallet has no open positions.
        case empty
        /// The load failed.
        /// - Parameter String: A user-facing error message.
        case failed(String)
    }

    /// The current view state.
    public private(set) var state: State = .needsAddress
    /// The currently-watched wallet address, or `nil` if none.
    public private(set) var address: String?
    /// Two-way bound text of the address entry field.
    public var addressInput: String = ""
    /// A validation error for the address field, or `nil` when valid.
    public private(set) var inputError: String?

    /// The wallet's closed positions (supplementary; empty if that fetch failed).
    public private(set) var closedPositions: [ClosedPosition] = []

    /// Use case that loads value + open positions.
    private let fetchPortfolio: FetchPortfolioUseCase
    /// Use case that loads closed positions.
    private let fetchClosed: FetchClosedPositionsUseCase
    /// Persists the watched address between launches.
    private let addressStore: WatchAddressStore

    /// Creates the view model, restoring any previously-saved watch address.
    /// - Parameters:
    ///   - fetchPortfolio: Loads value + positions.
    ///   - fetchClosed: Loads closed positions.
    ///   - addressStore: Persistent store for the watch address.
    public init(
        fetchPortfolio: FetchPortfolioUseCase,
        fetchClosed: FetchClosedPositionsUseCase,
        addressStore: WatchAddressStore = WatchAddressStore()
    ) {
        self.fetchPortfolio = fetchPortfolio
        self.fetchClosed = fetchClosed
        self.addressStore = addressStore
        self.address = addressStore.address
    }

    /// Entry point from the view's `.task`: loads if a wallet is saved, else prompts.
    public func start() async {
        guard address != nil else { state = .needsAddress; return }
        await load()
    }

    /// Validate and persist a watch address, then load.
    public func submit() async {
        guard let wallet = WalletAddress(addressInput) else {
            inputError = "Enter a valid 0x wallet address."
            return
        }
        inputError = nil
        address = wallet.value
        addressStore.save(wallet.value)
        await load()
    }

    /// Forgets the current wallet and returns to the address prompt.
    public func changeWallet() {
        address = nil
        addressInput = ""
        addressStore.clear()
        state = .needsAddress
    }

    /// Reloads the current wallet (pull-to-refresh).
    public func refresh() async {
        await load()
    }

    /// Loads the portfolio and (best-effort) closed positions for the watched wallet.
    /// Closed positions are secondary: a failure there just hides that section rather than
    /// failing the whole screen.
    private func load() async {
        guard let address else { state = .needsAddress; return }
        state = .loading
        do {
            let portfolio = try await fetchPortfolio.execute(address: address)
            // Closed positions are supplementary — a failure just hides that section.
            closedPositions = (try? await fetchClosed.execute(address: address)) ?? []
            state = portfolio.isEmpty ? .empty : .loaded(portfolio)
        } catch {
            state = .failed("Couldn't load this wallet. Pull to refresh.")
        }
    }
}

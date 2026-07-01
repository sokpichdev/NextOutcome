//
//  PortfolioViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import PortfolioDomain

@MainActor
@Observable
public final class PortfolioViewModel {
    public enum State {
        case needsAddress
        case loading
        case loaded(Portfolio)
        case empty
        case failed(String)
    }

    public private(set) var state: State = .needsAddress
    public private(set) var address: String?
    public var addressInput: String = ""
    public private(set) var inputError: String?

    public private(set) var closedPositions: [ClosedPosition] = []

    private let fetchPortfolio: FetchPortfolioUseCase
    private let fetchClosed: FetchClosedPositionsUseCase
    private let addressStore: WatchAddressStore

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

    public func changeWallet() {
        address = nil
        addressInput = ""
        addressStore.clear()
        state = .needsAddress
    }

    public func refresh() async {
        await load()
    }

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

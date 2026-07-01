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

    private let fetchPortfolio: FetchPortfolioUseCase
    private let defaults: UserDefaults
    private static let addressKey = "portfolio.watchAddress"

    public init(fetchPortfolio: FetchPortfolioUseCase, defaults: UserDefaults = .standard) {
        self.fetchPortfolio = fetchPortfolio
        self.defaults = defaults
        self.address = defaults.string(forKey: Self.addressKey)
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
        defaults.set(wallet.value, forKey: Self.addressKey)
        await load()
    }

    public func changeWallet() {
        address = nil
        addressInput = ""
        defaults.removeObject(forKey: Self.addressKey)
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
            state = portfolio.isEmpty ? .empty : .loaded(portfolio)
        } catch {
            state = .failed("Couldn't load this wallet. Pull to refresh.")
        }
    }
}

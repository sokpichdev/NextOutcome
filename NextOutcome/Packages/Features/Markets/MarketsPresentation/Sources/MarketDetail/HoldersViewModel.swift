//
//  HoldersViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import MarketsDomain

@MainActor
@Observable
/// Drives the "top holders" section on market detail.
public final class HoldersViewModel {
    /// What the holders section is currently showing.
    public enum State {
        /// Loading holders.
        case loading
        /// Loaded holders.
        case loaded([Holder])
        /// No holders to show.
        case empty
        /// The load failed.
        case failed
    }

    /// The current section state.
    public private(set) var state: State = .loading

    /// The market condition whose holders to load.
    private let conditionId: String
    /// Use case that fetches holders.
    private let fetchHolders: FetchHoldersUseCase

    /// Creates the view model.
    /// - Parameters:
    ///   - conditionId: The market condition to load holders for.
    ///   - fetchHolders: The holders use case.
    public init(conditionId: String, fetchHolders: FetchHoldersUseCase) {
        self.conditionId = conditionId
        self.fetchHolders = fetchHolders
    }

    /// Loads the top holders for the condition.
    public func load() async {
        do {
            let holders = try await fetchHolders.execute(conditionId: conditionId)
            state = holders.isEmpty ? .empty : .loaded(holders)
        } catch {
            state = .failed
        }
    }
}

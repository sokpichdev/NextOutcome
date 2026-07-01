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
public final class HoldersViewModel {
    public enum State {
        case loading
        case loaded([Holder])
        case empty
        case failed
    }

    public private(set) var state: State = .loading

    private let conditionId: String
    private let fetchHolders: FetchHoldersUseCase

    public init(conditionId: String, fetchHolders: FetchHoldersUseCase) {
        self.conditionId = conditionId
        self.fetchHolders = fetchHolders
    }

    public func load() async {
        do {
            let holders = try await fetchHolders.execute(conditionId: conditionId)
            state = holders.isEmpty ? .empty : .loaded(holders)
        } catch {
            state = .failed
        }
    }
}

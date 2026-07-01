//
//  MarketHoldersFactory.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI

/// App-provided builder for a `HoldersViewModel` given a market condition id.
/// Lets Market Detail load holders without importing the Data layer.
public struct MarketHoldersViewModelFactory: Sendable {
    private let make: @Sendable @MainActor (String) -> HoldersViewModel

    public init(_ make: @escaping @Sendable @MainActor (String) -> HoldersViewModel) {
        self.make = make
    }

    @MainActor
    public func callAsFunction(_ conditionId: String) -> HoldersViewModel {
        make(conditionId)
    }
}

private struct MarketHoldersFactoryKey: EnvironmentKey {
    static let defaultValue: MarketHoldersViewModelFactory? = nil
}

public extension EnvironmentValues {
    var marketHoldersFactory: MarketHoldersViewModelFactory? {
        get { self[MarketHoldersFactoryKey.self] }
        set { self[MarketHoldersFactoryKey.self] = newValue }
    }
}

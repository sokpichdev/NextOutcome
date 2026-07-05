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
    /// The closure (supplied by `AppContainer`) that builds a view model from a condition id.
    private let make: @Sendable @MainActor (String) -> HoldersViewModel

    /// Wraps a builder closure.
    /// - Parameter make: Builds a `HoldersViewModel` for a given condition id.
    public init(_ make: @escaping @Sendable @MainActor (String) -> HoldersViewModel) {
        self.make = make
    }

    /// Calls the factory like a function: `factory(conditionId)`.
    /// - Parameter conditionId: The market condition to build a view model for.
    /// - Returns: A ready-to-use `HoldersViewModel`.
    @MainActor
    public func callAsFunction(_ conditionId: String) -> HoldersViewModel {
        make(conditionId)
    }
}

/// Environment plumbing so the factory can be read with `@Environment(\.marketHoldersFactory)`.
private struct MarketHoldersFactoryKey: EnvironmentKey {
    /// No factory by default (previews/tests without a container).
    static let defaultValue: MarketHoldersViewModelFactory? = nil
}

public extension EnvironmentValues {
    /// The holders view-model factory injected by `AppContainer`; `nil` if not provided.
    var marketHoldersFactory: MarketHoldersViewModelFactory? {
        get { self[MarketHoldersFactoryKey.self] }
        set { self[MarketHoldersFactoryKey.self] = newValue }
    }
}

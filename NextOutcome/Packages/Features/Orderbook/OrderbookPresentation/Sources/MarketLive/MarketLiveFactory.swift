//
//  MarketLiveFactory.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI

/// App-provided builder for a `MarketLiveViewModel` given a CLOB token id.
/// Lets feature screens embed the live section without importing the Data layer.
public struct MarketLiveViewModelFactory: Sendable {
    /// The closure (supplied by `AppContainer`) that builds a view model from a token id.
    private let make: @Sendable @MainActor (String) -> MarketLiveViewModel

    /// Wraps a builder closure.
    /// - Parameter make: Builds a `MarketLiveViewModel` for a given token id.
    public init(_ make: @escaping @Sendable @MainActor (String) -> MarketLiveViewModel) {
        self.make = make
    }

    /// Calls the factory like a function: `factory(assetID)`.
    /// - Parameter assetID: The token to build a view model for.
    /// - Returns: A ready-to-use `MarketLiveViewModel`.
    @MainActor
    public func callAsFunction(_ assetID: String) -> MarketLiveViewModel {
        make(assetID)
    }
}

/// Environment plumbing so the factory can be read with `@Environment(\.marketLiveFactory)`.
private struct MarketLiveFactoryKey: EnvironmentKey {
    /// No factory by default (previews/tests without a container).
    static let defaultValue: MarketLiveViewModelFactory? = nil
}

public extension EnvironmentValues {
    /// The live-market view-model factory injected by `AppContainer`; `nil` if not provided.
    var marketLiveFactory: MarketLiveViewModelFactory? {
        get { self[MarketLiveFactoryKey.self] }
        set { self[MarketLiveFactoryKey.self] = newValue }
    }
}

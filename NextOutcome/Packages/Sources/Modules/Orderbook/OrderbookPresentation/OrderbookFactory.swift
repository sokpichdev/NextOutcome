//
//  OrderbookFactory.swift
//  NextOutcome
//

import SwiftUI

/// App-provided builder for an `OrderbookViewModel` given a CLOB token id. Lets
/// feature screens embed the expandable order book without importing the Data layer.
public struct OrderbookViewModelFactory: Sendable {
    /// The closure (supplied by `AppContainer`) that builds a view model from a token id.
    private let make: @Sendable @MainActor (String) -> OrderbookViewModel

    /// Wraps a builder closure.
    /// - Parameter make: Builds an `OrderbookViewModel` for a given token id.
    public init(_ make: @escaping @Sendable @MainActor (String) -> OrderbookViewModel) {
        self.make = make
    }

    /// Calls the factory like a function: `factory(assetID)`.
    /// - Parameter assetID: The token to build a view model for.
    /// - Returns: A ready-to-use `OrderbookViewModel`.
    @MainActor
    public func callAsFunction(_ assetID: String) -> OrderbookViewModel {
        make(assetID)
    }
}

/// Environment plumbing so the factory can be read with `@Environment(\.orderbookFactory)`.
private struct OrderbookFactoryKey: EnvironmentKey {
    /// No factory by default (previews/tests without a container).
    static let defaultValue: OrderbookViewModelFactory? = nil
}

public extension EnvironmentValues {
    /// The order book view-model factory injected by `AppContainer`; `nil` if not provided.
    var orderbookFactory: OrderbookViewModelFactory? {
        get { self[OrderbookFactoryKey.self] }
        set { self[OrderbookFactoryKey.self] = newValue }
    }
}

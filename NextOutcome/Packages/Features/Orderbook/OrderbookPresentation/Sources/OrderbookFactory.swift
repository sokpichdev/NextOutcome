//
//  OrderbookFactory.swift
//  NextOutcome
//

import SwiftUI

/// App-provided builder for an `OrderbookViewModel` given a CLOB token id. Lets
/// feature screens embed the expandable order book without importing the Data layer.
public struct OrderbookViewModelFactory: Sendable {
    private let make: @Sendable @MainActor (String) -> OrderbookViewModel

    public init(_ make: @escaping @Sendable @MainActor (String) -> OrderbookViewModel) {
        self.make = make
    }

    @MainActor
    public func callAsFunction(_ assetID: String) -> OrderbookViewModel {
        make(assetID)
    }
}

private struct OrderbookFactoryKey: EnvironmentKey {
    static let defaultValue: OrderbookViewModelFactory? = nil
}

public extension EnvironmentValues {
    var orderbookFactory: OrderbookViewModelFactory? {
        get { self[OrderbookFactoryKey.self] }
        set { self[OrderbookFactoryKey.self] = newValue }
    }
}

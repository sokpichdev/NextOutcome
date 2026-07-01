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
    private let make: @Sendable @MainActor (String) -> MarketLiveViewModel

    public init(_ make: @escaping @Sendable @MainActor (String) -> MarketLiveViewModel) {
        self.make = make
    }

    @MainActor
    public func callAsFunction(_ assetID: String) -> MarketLiveViewModel {
        make(assetID)
    }
}

private struct MarketLiveFactoryKey: EnvironmentKey {
    static let defaultValue: MarketLiveViewModelFactory? = nil
}

public extension EnvironmentValues {
    var marketLiveFactory: MarketLiveViewModelFactory? {
        get { self[MarketLiveFactoryKey.self] }
        set { self[MarketLiveFactoryKey.self] = newValue }
    }
}

//
//  BTCLiveFactory.swift
//  NextOutcome
//

import SwiftUI

/// Parameters needed to open the BTC 5-minute live screen for a resolved event.
public struct BTCLiveContext: Sendable {
    public let assetID: String     // CLOB token id for the "Up" outcome
    public let eventID: String     // gamma event id (for the /trades ticker)
    public let windowEnd: Date     // when the 5-minute window closes

    public init(assetID: String, eventID: String, windowEnd: Date) {
        self.assetID = assetID
        self.eventID = eventID
        self.windowEnd = windowEnd
    }
}

/// App-provided builder for a `BTCLiveViewModel`, so feature screens can open the live
/// BTC screen without importing the Data layer. `onQuickBet` forwards Up/Down taps to
/// the host's trade-sheet / order-flow entry point.
public struct BTCLiveViewModelFactory: Sendable {
    private let make: @Sendable @MainActor (BTCLiveContext, @escaping @MainActor (BTCLiveViewModel.BetSide) -> Void) -> BTCLiveViewModel

    public init(
        _ make: @escaping @Sendable @MainActor (BTCLiveContext, @escaping @MainActor (BTCLiveViewModel.BetSide) -> Void) -> BTCLiveViewModel
    ) {
        self.make = make
    }

    @MainActor
    public func callAsFunction(
        _ context: BTCLiveContext,
        onQuickBet: @escaping @MainActor (BTCLiveViewModel.BetSide) -> Void
    ) -> BTCLiveViewModel {
        make(context, onQuickBet)
    }
}

private struct BTCLiveFactoryKey: EnvironmentKey {
    static let defaultValue: BTCLiveViewModelFactory? = nil
}

public extension EnvironmentValues {
    var btcLiveFactory: BTCLiveViewModelFactory? {
        get { self[BTCLiveFactoryKey.self] }
        set { self[BTCLiveFactoryKey.self] = newValue }
    }
}

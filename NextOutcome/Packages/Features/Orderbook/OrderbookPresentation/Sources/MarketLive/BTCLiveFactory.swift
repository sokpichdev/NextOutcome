//
//  BTCLiveFactory.swift
//  NextOutcome
//

import SwiftUI

/// Parameters needed to open the BTC 5-minute live screen for a resolved event.
public struct BTCLiveContext: Sendable {
    /// The CLOB token id for the "Up" outcome.
    public let assetID: String     // CLOB token id for the "Up" outcome
    /// The Gamma event id, used by the recent-trades ticker.
    public let eventID: String     // gamma event id (for the /trades ticker)
    /// When the current 5-minute window closes (drives the countdown).
    public let windowEnd: Date     // when the 5-minute window closes

    /// Creates the context needed to open the BTC live screen.
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
    /// The closure (supplied by `AppContainer`) that builds the view model from a context
    /// and a quick-bet callback.
    private let make: @Sendable @MainActor (BTCLiveContext, @escaping @MainActor (BTCLiveViewModel.BetSide) -> Void) -> BTCLiveViewModel

    /// Wraps a builder closure.
    /// - Parameter make: Builds a `BTCLiveViewModel` from a context and quick-bet handler.
    public init(
        _ make: @escaping @Sendable @MainActor (BTCLiveContext, @escaping @MainActor (BTCLiveViewModel.BetSide) -> Void) -> BTCLiveViewModel
    ) {
        self.make = make
    }

    /// Calls the factory like a function: `factory(context, onQuickBet:)`.
    /// - Parameters:
    ///   - context: The resolved event details (asset, event, window end).
    ///   - onQuickBet: Called when the user taps Up/Down; the host opens its trade flow.
    /// - Returns: A ready-to-use `BTCLiveViewModel`.
    @MainActor
    public func callAsFunction(
        _ context: BTCLiveContext,
        onQuickBet: @escaping @MainActor (BTCLiveViewModel.BetSide) -> Void
    ) -> BTCLiveViewModel {
        make(context, onQuickBet)
    }
}

/// Environment plumbing so the factory can be read with `@Environment(\.btcLiveFactory)`.
private struct BTCLiveFactoryKey: EnvironmentKey {
    /// No factory by default (previews/tests without a container).
    static let defaultValue: BTCLiveViewModelFactory? = nil
}

public extension EnvironmentValues {
    /// The BTC-live view-model factory injected by `AppContainer`; `nil` if not provided.
    var btcLiveFactory: BTCLiveViewModelFactory? {
        get { self[BTCLiveFactoryKey.self] }
        set { self[BTCLiveFactoryKey.self] = newValue }
    }
}

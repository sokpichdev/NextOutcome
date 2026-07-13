//
//  BTCLiveFactory.swift
//  NextOutcome
//

import SwiftUI

/// Parameters needed to open the crypto live screen for an Up/Down event.
public struct BTCLiveContext: Sendable {
    /// The CLOB token id for the "Up" outcome.
    public let assetID: String     // CLOB token id for the "Up" outcome
    /// The Gamma event id, used by the recent-trades ticker.
    public let eventID: String     // gamma event id (for the /trades ticker)
    /// When the current window closes (drives the countdown).
    public let windowEnd: Date
    /// The window length in seconds (e.g. 300 for a 5-minute round), derived from the
    /// event's recurrence — the screen opens for 5m/15m/1h/… rounds, not just 5-minute ones.
    public let windowInterval: TimeInterval
    /// The underlying crypto asset's ticker symbol (e.g. "BTC", "ETH"), used to query
    /// the real dollar spot-price feed. This screen isn't BTC-only — the Crypto hub
    /// opens it for any Up/Down coin — so this must reflect the actual event's asset,
    /// not be assumed.
    public let symbol: String

    /// Creates the context needed to open the crypto live screen.
    public init(assetID: String, eventID: String, windowEnd: Date, windowInterval: TimeInterval = 300, symbol: String) {
        self.assetID = assetID
        self.eventID = eventID
        self.windowEnd = windowEnd
        self.windowInterval = windowInterval
        self.symbol = symbol
    }

    /// Derives the window length from an event's Gamma recurrence slug (e.g.
    /// `"btc-up-or-down-5m"` → 300, `"…-hourly"` → 3600). Falls back to 5 minutes for an
    /// unknown or missing recurrence.
    /// - Parameter recurrence: The event's recurrence slug.
    /// - Returns: The window length in seconds.
    public static func windowInterval(forRecurrence recurrence: String?) -> TimeInterval {
        guard let recurrence = recurrence?.lowercased() else { return 300 }
        if recurrence.hasSuffix("-5m") { return 300 }
        if recurrence.hasSuffix("-15m") { return 900 }
        if recurrence.hasSuffix("-30m") { return 1_800 }
        if recurrence.hasSuffix("-1h") || recurrence.hasSuffix("hourly") { return 3_600 }
        if recurrence.hasSuffix("-4h") { return 14_400 }
        if recurrence.hasSuffix("daily") || recurrence.hasSuffix("-1d") { return 86_400 }
        return 300
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

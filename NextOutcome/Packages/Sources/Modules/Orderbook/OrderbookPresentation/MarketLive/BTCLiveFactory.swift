//
//  BTCLiveFactory.swift
//  NextOutcome
//

import SwiftUI

/// Parameters needed to open the crypto Up/Down live screen for a resolved event.
public struct BTCLiveContext: Sendable {
    /// The CLOB token id for the "Up" outcome.
    public let assetID: String     // CLOB token id for the "Up" outcome
    /// The Gamma event id, used by the recent-trades ticker.
    public let eventID: String     // gamma event id (for the /trades ticker)
    /// When the current window closes (drives the countdown).
    public let windowEnd: Date
    /// The market's name for the header, e.g. "BTC Up or Down 5m". Supplied by the caller
    /// because the series title lives on the Markets slice's `Event`, which this screen
    /// deliberately doesn't import.
    public let title: String
    /// The market's icon (the coin logo) for the header.
    public let iconURL: URL?
    /// The underlying crypto asset's ticker symbol (e.g. "BTC", "ETH"), used to query
    /// the real dollar spot-price feed. This screen isn't BTC-only — the Crypto hub
    /// opens it for any Up/Down coin — so this must reflect the actual event's asset,
    /// not be assumed.
    public let symbol: String
    /// How long the window runs, in seconds. Like `symbol`, this must reflect the actual
    /// event: the hub opens this screen for every Up/Down cadence (5m through daily), and
    /// the window open — the price to beat, the spot-price range, the chart title — is
    /// `windowEnd` minus this. Defaults to the 5-minute series.
    public let windowInterval: TimeInterval

    /// Creates the context needed to open the live screen.
    public init(
        assetID: String,
        eventID: String,
        windowEnd: Date,
        title: String,
        iconURL: URL?,
        symbol: String,
        windowInterval: TimeInterval = 300
    ) {
        self.assetID = assetID
        self.eventID = eventID
        self.windowEnd = windowEnd
        self.title = title
        self.iconURL = iconURL
        self.symbol = symbol
        self.windowInterval = windowInterval
    }
}

/// App-provided builder for a `BTCLiveViewModel`, so feature screens can open the live
/// BTC screen without importing the Data layer. `onQuickBet` forwards an amount tile's
/// (side, stake) to the host's trade-sheet / order-flow entry point.
public struct BTCLiveViewModelFactory: Sendable {
    /// The closure (supplied by `AppContainer`) that builds the view model from a context
    /// and a quick-bet callback.
    private let make: @Sendable @MainActor (BTCLiveContext, @escaping @MainActor (BTCLiveViewModel.BetSide, Int) -> Void) -> BTCLiveViewModel

    /// Wraps a builder closure.
    /// - Parameter make: Builds a `BTCLiveViewModel` from a context and quick-bet handler.
    public init(
        _ make: @escaping @Sendable @MainActor (BTCLiveContext, @escaping @MainActor (BTCLiveViewModel.BetSide, Int) -> Void) -> BTCLiveViewModel
    ) {
        self.make = make
    }

    /// Calls the factory like a function: `factory(context, onQuickBet:)`.
    /// - Parameters:
    ///   - context: The resolved event details (asset, event, window end).
    ///   - onQuickBet: Called with the selected side and stake when an amount tile is
    ///     tapped; the host opens its trade flow already holding that amount.
    /// - Returns: A ready-to-use `BTCLiveViewModel`.
    @MainActor
    public func callAsFunction(
        _ context: BTCLiveContext,
        onQuickBet: @escaping @MainActor (BTCLiveViewModel.BetSide, Int) -> Void
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

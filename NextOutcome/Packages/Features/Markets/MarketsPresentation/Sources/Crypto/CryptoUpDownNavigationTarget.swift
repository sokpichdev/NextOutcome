import Foundation
import MarketsDomain
import OrderbookPresentation

/// Navigation payload for opening the rich `BTCLiveView` screen from the Crypto hub.
/// Bundles what `BTCLiveContext` needs (asset id, event id, window end) plus the
/// underlying `Market`, which `BTCLiveContext` alone doesn't carry but the destination
/// needs in order to open a `TradeSheet` on quick-bet.
public struct CryptoUpDownNavigationTarget: Hashable {
    /// The CLOB token id for the "Up" outcome.
    public let assetID: String
    /// The Gamma event id.
    public let eventID: String
    /// When the current window closes (drives the countdown).
    public let windowEnd: Date
    /// The window length in seconds (e.g. 300 for a 5-minute round), derived from the event's
    /// recurrence so the live screen isn't assumed to be 5-minute.
    public let windowInterval: TimeInterval
    /// The underlying crypto asset's ticker symbol (e.g. "BTC", "ETH"), used to query
    /// the real dollar spot-price feed — this screen opens for any Up/Down coin.
    public let symbol: String
    /// The underlying market, needed to open a `TradeSheet` on quick-bet.
    public let market: Market

    /// Creates the navigation target.
    public init(assetID: String, eventID: String, windowEnd: Date, windowInterval: TimeInterval = 300, symbol: String, market: Market) {
        self.assetID = assetID
        self.eventID = eventID
        self.windowEnd = windowEnd
        self.windowInterval = windowInterval
        self.symbol = symbol
        self.market = market
    }

    /// The `BTCLiveContext` this target carries, for building the live view model.
    public var liveContext: BTCLiveContext {
        BTCLiveContext(assetID: assetID, eventID: eventID, windowEnd: windowEnd, windowInterval: windowInterval, symbol: symbol)
    }
}

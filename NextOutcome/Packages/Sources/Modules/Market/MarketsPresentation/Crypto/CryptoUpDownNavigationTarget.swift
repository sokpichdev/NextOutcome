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
    /// The underlying crypto asset's ticker symbol (e.g. "BTC", "ETH"), used to query
    /// the real dollar spot-price feed — this screen opens for any Up/Down coin.
    public let symbol: String
    /// How long this event's window runs, in seconds. The hub opens the live screen for
    /// every Up/Down cadence, not just the 5-minute one, and the destination derives the
    /// window open (and therefore the price to beat, the spot-price range and the chart's
    /// title) from `windowEnd` minus this — so a wrong value shows the wrong market.
    public let windowInterval: TimeInterval
    /// The series name for the live screen's header, e.g. "BTC Up or Down 5m". Carried
    /// here because it lives on the `Event`, which the Orderbook slice can't see.
    public let title: String
    /// The market's icon (the coin logo) for that header.
    public let iconURL: URL?
    /// The underlying market, needed to open a `TradeSheet` on quick-bet.
    public let market: Market

    /// Creates the navigation target.
    public init(
        assetID: String,
        eventID: String,
        windowEnd: Date,
        symbol: String,
        windowInterval: TimeInterval,
        title: String,
        iconURL: URL?,
        market: Market
    ) {
        self.assetID = assetID
        self.eventID = eventID
        self.windowEnd = windowEnd
        self.symbol = symbol
        self.windowInterval = windowInterval
        self.title = title
        self.iconURL = iconURL
        self.market = market
    }

    /// The `BTCLiveContext` this target carries, for building the live view model.
    public var liveContext: BTCLiveContext {
        BTCLiveContext(
            assetID: assetID, eventID: eventID, windowEnd: windowEnd,
            title: title, iconURL: iconURL,
            symbol: symbol, windowInterval: windowInterval
        )
    }
}

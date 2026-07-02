import SwiftUI
import OrderbookDomain

/// App-provided async fetch of price history for one asset id, so feature screens can
/// build charts without importing the Data layer or opening a websocket.
public struct PriceHistoryProvider: Sendable {
    private let fetch: @Sendable (String, PriceHistoryInterval) async -> [PriceHistoryPoint]
    public init(_ fetch: @escaping @Sendable (String, PriceHistoryInterval) async -> [PriceHistoryPoint]) {
        self.fetch = fetch
    }
    public func callAsFunction(_ assetID: String, _ interval: PriceHistoryInterval) async -> [PriceHistoryPoint] {
        await fetch(assetID, interval)
    }
}

private struct PriceHistoryProviderKey: EnvironmentKey {
    static let defaultValue: PriceHistoryProvider? = nil
}
public extension EnvironmentValues {
    var priceHistoryProvider: PriceHistoryProvider? {
        get { self[PriceHistoryProviderKey.self] }
        set { self[PriceHistoryProviderKey.self] = newValue }
    }
}

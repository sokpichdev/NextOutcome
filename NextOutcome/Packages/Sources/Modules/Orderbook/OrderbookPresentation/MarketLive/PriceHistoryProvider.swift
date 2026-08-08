import SwiftUI
import OrderbookDomain

/// App-provided async fetch of price history for one asset id, so feature screens can
/// build charts without importing the Data layer or opening a websocket.
public struct PriceHistoryProvider: Sendable {
    /// The closure (supplied by `AppContainer`) that actually fetches the history.
    private let fetch: @Sendable (String, PriceHistoryInterval) async throws -> [PriceHistoryPoint]
    /// Wraps a fetch closure.
    /// - Parameter fetch: Fetches history for a token and interval.
    public init(_ fetch: @escaping @Sendable (String, PriceHistoryInterval) async throws -> [PriceHistoryPoint]) {
        self.fetch = fetch
    }
    /// Calls the provider like a function: `provider(assetID, interval)`.
    /// - Parameters:
    ///   - assetID: The token to fetch history for.
    ///   - interval: The time window.
    /// - Returns: The price-history points.
    /// - Throws: A networking error if the fetch fails.
    public func callAsFunction(_ assetID: String, _ interval: PriceHistoryInterval) async throws -> [PriceHistoryPoint] {
        try await fetch(assetID, interval)
    }
}

/// Environment plumbing so the provider can be read with `@Environment(\.priceHistoryProvider)`.
private struct PriceHistoryProviderKey: EnvironmentKey {
    /// No provider by default (previews/tests without a container).
    static let defaultValue: PriceHistoryProvider? = nil
}
public extension EnvironmentValues {
    /// The price-history provider injected by `AppContainer`; `nil` if not provided.
    var priceHistoryProvider: PriceHistoryProvider? {
        get { self[PriceHistoryProviderKey.self] }
        set { self[PriceHistoryProviderKey.self] = newValue }
    }
}

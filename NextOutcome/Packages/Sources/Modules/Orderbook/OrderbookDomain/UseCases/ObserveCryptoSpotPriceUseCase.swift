//
//  ObserveCryptoSpotPriceUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 13/07/2026.
//

import Foundation

/// Streams the live dollar spot-price series: seeds with the REST history (so the chart
/// isn't blank on entry), then appends each live socket sample and re-yields the growing
/// series. Mirrors `ObserveOrderBookUseCase`'s seed-then-fold contract, but for the real
/// USD price series that drives the BTC live screen's "Price"/"Candles" modes and the
/// "Current Price" header — replacing the previous 5-second REST poll.
public struct ObserveCryptoSpotPriceUseCase: Sendable {
    /// The REST source used to seed the initial history.
    private let repository: CryptoSpotPriceRepository
    /// The realtime source of live spot-price samples.
    private let stream: CryptoSpotPriceStreaming

    /// Creates the use case.
    /// - Parameters:
    ///   - repository: Supplies the initial REST history seed.
    ///   - stream: Supplies live spot-price samples.
    public init(repository: CryptoSpotPriceRepository, stream: CryptoSpotPriceStreaming) {
        self.repository = repository
        self.stream = stream
    }

    /// Streams the growing dollar spot-price series for one asset.
    ///
    /// Yields the REST-seeded history immediately, then a new series (history + all live
    /// samples so far) each time a socket sample arrives. Cancelling the consuming task
    /// tears down the subscription.
    /// - Parameters:
    ///   - symbol: The asset symbol, e.g. `"BTC"`.
    ///   - eventStart: The window's open time (used to seed the REST history).
    ///   - eventEnd: The window's close time (used to seed the REST history).
    /// - Returns: An async stream of successive spot-price series.
    public func execute(symbol: String, eventStart: Date, eventEnd: Date) -> AsyncStream<[CryptoSpotPricePoint]> {
        AsyncStream { continuation in
            let task = Task {
                var series: [CryptoSpotPricePoint] = []

                // Seed with the REST history so the chart has data immediately.
                if let history = try? await repository.spotPriceHistory(
                    symbol: symbol, eventStart: eventStart, eventEnd: eventEnd
                ) {
                    series = history
                    continuation.yield(series)
                }

                for await point in stream.prices(symbol: symbol) {
                    series.append(point)
                    continuation.yield(series)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

//
//  CandleAggregator.swift
//  NextOutcome
//

import Foundation

/// A single price sample (timestamp + fractional price in 0…1) consumed by the
/// candle aggregator. Structurally identical to `PriceHistoryPoint`; aliased so the
/// aggregator reads with the domain vocabulary from the task brief.
public typealias PricePoint = PriceHistoryPoint

/// Open/High/Low/Close candle for one fixed time bucket.
public struct Candle: Equatable, Sendable {
    public let open: Decimal
    public let high: Decimal
    public let low: Decimal
    public let close: Decimal
    public let start: Date

    public init(open: Decimal, high: Decimal, low: Decimal, close: Decimal, start: Date) {
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.start = start
    }
}

/// Pure-domain OHLC aggregation. Buckets price samples into fixed intervals aligned to
/// interval boundaries from the epoch; empty interior buckets carry the previous close.
public enum CandleAggregator {
    /// Buckets `points` into `interval`-second candles.
    /// - Buckets align to interval boundaries measured from `timeIntervalSince1970`.
    /// - An empty bucket between two populated buckets emits a flat candle at the
    ///   previous close (open == high == low == close).
    public static func candles(from points: [PricePoint], interval: TimeInterval) -> [Candle] {
        guard interval > 0, !points.isEmpty else { return [] }

        let sorted = points.sorted { $0.date < $1.date }

        func bucketStart(_ date: Date) -> TimeInterval {
            (date.timeIntervalSince1970 / interval).rounded(.down) * interval
        }

        // Group samples by their aligned bucket-start second.
        var grouped: [TimeInterval: [PricePoint]] = [:]
        for point in sorted {
            grouped[bucketStart(point.date), default: []].append(point)
        }

        let firstBucket = bucketStart(sorted.first!.date)
        let lastBucket = bucketStart(sorted.last!.date)

        var result: [Candle] = []
        var previousClose: Decimal?
        var bucket = firstBucket
        while bucket <= lastBucket {
            let start = Date(timeIntervalSince1970: bucket)
            if let samples = grouped[bucket], !samples.isEmpty {
                let prices = samples.map(\.price)
                let candle = Candle(
                    open: prices.first!,
                    high: prices.max()!,
                    low: prices.min()!,
                    close: prices.last!,
                    start: start
                )
                result.append(candle)
                previousClose = candle.close
            } else if let carried = previousClose {
                result.append(Candle(open: carried, high: carried, low: carried, close: carried, start: start))
            }
            bucket += interval
        }
        return result
    }
}

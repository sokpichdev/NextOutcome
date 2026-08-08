//
//  CandleAggregator.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import Foundation

/// A single price sample (timestamp + fractional price in 0…1) consumed by the
/// candle aggregator. Structurally identical to `PriceHistoryPoint`; aliased so the
/// aggregator reads with the domain vocabulary from the task brief.
public typealias PricePoint = PriceHistoryPoint

/// Open/High/Low/Close candle for one fixed time bucket.
public struct Candle: Equatable, Sendable {
    /// The first price in the bucket.
    public let open: Decimal
    /// The highest price in the bucket.
    public let high: Decimal
    /// The lowest price in the bucket.
    public let low: Decimal
    /// The last price in the bucket.
    public let close: Decimal
    /// The start time of the bucket.
    public let start: Date

    /// Creates an OHLC candle.
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

    /// Folds one live price tick into an existing candle series.
    ///
    /// - A tick inside the newest candle's bucket mutates that forming candle: close
    ///   follows the tick and high/low stretch to include it (the open never moves).
    /// - A tick in a later bucket appends a fresh candle whose OHLC all equal the tick.
    /// - A stale tick (from before the newest bucket) is dropped — live ticks never
    ///   rewrite closed candles.
    /// - Parameters:
    ///   - candles: The series so far, oldest first.
    ///   - tick: The live price sample to fold in.
    ///   - interval: The candle width in seconds.
    /// - Returns: The updated series.
    public static func folding(
        _ candles: [Candle], with tick: CryptoSpotPricePoint, interval: TimeInterval
    ) -> [Candle] {
        guard interval > 0 else { return candles }
        let slot = (tick.date.timeIntervalSince1970 / interval).rounded(.down) * interval
        let bucketStart = Date(timeIntervalSince1970: slot)

        guard let last = candles.last else {
            return [Candle(open: tick.price, high: tick.price, low: tick.price, close: tick.price, start: bucketStart)]
        }
        if bucketStart > last.start {
            return candles + [Candle(open: tick.price, high: tick.price, low: tick.price, close: tick.price, start: bucketStart)]
        }
        guard bucketStart == last.start else { return candles }

        var updated = candles
        updated[updated.count - 1] = Candle(
            open: last.open,
            high: Swift.max(last.high, tick.price),
            low: Swift.min(last.low, tick.price),
            close: tick.price,
            start: last.start
        )
        return updated
    }
}

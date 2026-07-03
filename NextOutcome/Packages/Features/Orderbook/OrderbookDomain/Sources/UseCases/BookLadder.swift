//
//  BookLadder.swift
//  NextOutcome
//

import Foundation

/// Presentation-ready view of an `OrderBook`: each side pre-sorted with a running
/// (cumulative) size, plus the spread — everything `OrderbookView`'s depth bars need,
/// with no formatting or UI concerns. Pure, no I/O — trivially unit-testable.
public struct BookLadder: Equatable, Sendable {
    public struct Level: Equatable, Sendable {
        public let price: Decimal
        public let size: Decimal
        public let cumulative: Decimal

        public init(price: Decimal, size: Decimal, cumulative: Decimal) {
            self.price = price
            self.size = size
            self.cumulative = cumulative
        }
    }

    /// Ascending price (lowest/nearest-to-spread first), cumulative growing outward.
    public let asks: [Level]
    /// Descending price (highest/nearest-to-spread first), cumulative growing outward.
    public let bids: [Level]
    /// Best-ask − best-bid, in cents. `0` when either side is empty.
    public let spreadCents: Decimal

    public init(asks: [Level], bids: [Level], spreadCents: Decimal) {
        self.asks = asks
        self.bids = bids
        self.spreadCents = spreadCents
    }

    public static func from(_ book: OrderBook) -> BookLadder {
        BookLadder(
            asks: cumulativeLevels(book.asks),
            bids: cumulativeLevels(book.bids),
            spreadCents: spreadCents(bestBid: book.bids.first?.price, bestAsk: book.asks.first?.price)
        )
    }

    /// Applies one socket delta (upsert, or removal when `size == 0`) and returns a
    /// new ladder with cumulative sums and spread recomputed. `LevelChange` is the
    /// domain's existing socket-delta type (see `OrderBookEvent.priceChanges`) —
    /// this is the brief's `PriceChange`.
    public func applying(_ change: LevelChange) -> BookLadder {
        switch change.side {
        case .bid:
            let updated = upsert(change, into: bids).sorted { $0.price > $1.price }
            return BookLadder(
                asks: asks,
                bids: Self.cumulativeLevels(updated),
                spreadCents: Self.spreadCents(bestBid: updated.first?.price, bestAsk: asks.first?.price)
            )
        case .ask:
            let updated = upsert(change, into: asks).sorted { $0.price < $1.price }
            return BookLadder(
                asks: Self.cumulativeLevels(updated),
                bids: bids,
                spreadCents: Self.spreadCents(bestBid: bids.first?.price, bestAsk: updated.first?.price)
            )
        }
    }

    // MARK: - Helpers

    private func upsert(_ change: LevelChange, into levels: [Level]) -> [PriceLevel] {
        var byPrice = Dictionary(uniqueKeysWithValues: levels.map { ($0.price, $0.size) })
        if change.size > 0 {
            byPrice[change.price] = change.size
        } else {
            byPrice[change.price] = nil
        }
        return byPrice.map { PriceLevel(price: $0.key, size: $0.value) }
    }

    private static func cumulativeLevels(_ levels: [PriceLevel]) -> [Level] {
        var running: Decimal = 0
        return levels.map { level in
            running += level.size
            return Level(price: level.price, size: level.size, cumulative: running)
        }
    }

    private static func cumulativeLevels(_ levels: [Level]) -> [Level] {
        cumulativeLevels(levels.map { PriceLevel(price: $0.price, size: $0.size) })
    }

    private static func spreadCents(bestBid: Decimal?, bestAsk: Decimal?) -> Decimal {
        guard let bestBid, let bestAsk else { return 0 }
        return (bestAsk - bestBid) * 100
    }
}

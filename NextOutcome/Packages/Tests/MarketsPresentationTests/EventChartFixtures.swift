import Foundation
import MarketsDomain
import OrderbookDomain

/// Shared fixtures for `EventChartViewModel` tests.
extension Market {
    static func fixture(id: String = "m1", yes: Double = 0.5) -> Market {
        Market(id: id, question: id, slug: id,
               outcomes: [Outcome(id: "\(id)-yes", title: "Yes", price: Decimal(yes)),
                          Outcome(id: "\(id)-no", title: "No", price: Decimal(1 - yes))],
               volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil)
    }
}

extension Event {
    static func fixture(markets: [Market] = [.fixture()]) -> Event {
        Event(id: "e1", title: "Test Event", slug: "test-event",
              markets: markets, volume: 0, imageURL: nil, tags: [])
    }
}

extension PriceHistoryPoint {
    static func fixture(price: Decimal = 0.5) -> PriceHistoryPoint {
        PriceHistoryPoint(date: Date(), price: price)
    }
}

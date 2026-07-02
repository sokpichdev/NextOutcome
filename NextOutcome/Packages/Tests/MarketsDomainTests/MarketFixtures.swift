import Foundation
@testable import MarketsDomain

/// Shared fixture for `MarketsDomainTests`.
extension Market {
    static func fixture(
        id: String = "m1",
        question: String = "Test market",
        sportsMarketType: String? = nil,
        groupItemTitle: String? = nil
    ) -> Market {
        Market(
            id: id,
            question: question,
            slug: id,
            outcomes: [],
            volume: 0,
            liquidity: 0,
            endDate: nil,
            isResolved: false,
            imageURL: nil,
            sportsMarketType: sportsMarketType,
            groupItemTitle: groupItemTitle
        )
    }
}

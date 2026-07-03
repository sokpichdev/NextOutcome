import Foundation
@testable import MarketsDomain

/// Shared fixture for `MarketsDomainTests`.
extension Market {
    static func fixture(
        id: String = "m1",
        question: String = "Test market",
        sportsMarketType: String? = nil,
        groupItemTitle: String? = nil,
        yesPrice: Double? = nil
    ) -> Market {
        let outcomes: [Outcome] = yesPrice.map {
            [Outcome(id: "\(id)-yes", title: "Yes", price: Decimal($0)),
             Outcome(id: "\(id)-no", title: "No", price: Decimal(1 - $0))]
        } ?? []
        return Market(
            id: id,
            question: question,
            slug: id,
            outcomes: outcomes,
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

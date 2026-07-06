import XCTest
import MarketsDomain
@testable import MarketsPresentation

final class RaceLeanClassifierTests: XCTestCase {
    private func market(_ title: String, yes: Double) -> Market {
        Market(id: title, question: title, slug: title,
               outcomes: [Outcome(id: "\(title)-yes", title: "Yes", price: Decimal(yes)),
                          Outcome(id: "\(title)-no", title: "No", price: Decimal(1 - yes))],
               volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil,
               groupItemTitle: title)
    }

    func test_probabilityThresholds_matchLegendBuckets() {
        XCTAssertEqual(RaceLeanClassifier.lean(democraticProbability: 0.99), .safeD)
        XCTAssertEqual(RaceLeanClassifier.lean(democraticProbability: 0.95), .safeD)
        XCTAssertEqual(RaceLeanClassifier.lean(democraticProbability: 0.85), .likelyD)
        XCTAssertEqual(RaceLeanClassifier.lean(democraticProbability: 0.65), .leanD)
        XCTAssertEqual(RaceLeanClassifier.lean(democraticProbability: 0.50), .tossUp)
        XCTAssertEqual(RaceLeanClassifier.lean(democraticProbability: 0.30), .leanR)
        XCTAssertEqual(RaceLeanClassifier.lean(democraticProbability: 0.10), .likelyR)
        XCTAssertEqual(RaceLeanClassifier.lean(democraticProbability: 0.01), .safeR)
    }

    func test_democraticProbability_findsPartyMarket_caseInsensitively() {
        let markets = [market("Republican", yes: 0.4), market("Democrat", yes: 0.6)]
        XCTAssertEqual(RaceLeanClassifier.democraticProbability(in: markets), 0.6)
    }

    func test_democraticProbability_returnsNil_whenNoPartyMarketPresent() {
        let markets = [market("Xavier Becerra", yes: 0.92), market("Steve Hilton", yes: 0.08)]
        XCTAssertNil(RaceLeanClassifier.democraticProbability(in: markets))
    }

    func test_leanForRaceMarkets_noPartyMarket_isNoRace() {
        let markets = [market("Xavier Becerra", yes: 0.92), market("Steve Hilton", yes: 0.08)]
        XCTAssertEqual(RaceLeanClassifier.lean(forRaceMarkets: markets), .noRace)
    }

    func test_leanForRaceMarkets_withPartyMarket_classifiesFromItsProbability() {
        let markets = [market("Democrat", yes: 0.7), market("Republican", yes: 0.3)]
        XCTAssertEqual(RaceLeanClassifier.lean(forRaceMarkets: markets), .leanD)
    }
}

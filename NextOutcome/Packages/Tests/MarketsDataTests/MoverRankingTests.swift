import XCTest
import MarketsDomain
@testable import MarketsData

final class MoverRankingTests: XCTestCase {
    private func mover(
        _ id: String,
        eventSlug: String = "e",
        probability: Decimal = 0.5,
        dayChange: Decimal = 0.1,
        volume24h: Decimal = 100
    ) -> Mover {
        Mover(id: id, question: id, eventSlug: eventSlug, eventTitle: id, imageURL: nil,
              probability: probability, dayChange: dayChange, volume24h: volume24h)
    }

    func test_sortsByMagnitude_descending_regardlessOfDirection() {
        let up = mover("up", dayChange: 0.2)
        let down = mover("down", dayChange: -0.6)
        let small = mover("small", dayChange: 0.05)

        let ranked = MoverRanking.rank([up, down, small])

        XCTAssertEqual(ranked.map(\.id), ["down", "up", "small"])
    }

    func test_tiedMagnitude_higherVolumeWinsTiebreak() {
        let lowVol = mover("low", dayChange: 0.3, volume24h: 100)
        let highVol = mover("high", dayChange: -0.3, volume24h: 5000)

        let ranked = MoverRanking.rank([lowVol, highVol])

        XCTAssertEqual(ranked.map(\.id), ["high", "low"])
    }

    func test_dropsMoversWithNoParentEvent() {
        let withEvent = mover("has-event", eventSlug: "e1")
        let noEvent = mover("no-event", eventSlug: "")

        let ranked = MoverRanking.rank([withEvent, noEvent])

        XCTAssertEqual(ranked.map(\.id), ["has-event"])
    }

    func test_dropsNearResolvedNoise_belowMinProbability() {
        let noise = mover("noise", probability: 0.001)
        let real = mover("real", probability: 0.08)

        let ranked = MoverRanking.rank([noise, real])

        XCTAssertEqual(ranked.map(\.id), ["real"])
    }

    func test_dropsNearResolvedNoise_aboveMaxProbability() {
        let noise = mover("noise", probability: 0.999)
        let real = mover("real", probability: 0.85)

        let ranked = MoverRanking.rank([noise, real])

        XCTAssertEqual(ranked.map(\.id), ["real"])
    }

    func test_deduplicatesByID_keepingFirstOccurrence() {
        let first = mover("dup", dayChange: 0.4)
        let duplicate = mover("dup", dayChange: 0.4)

        let ranked = MoverRanking.rank([first, duplicate])

        XCTAssertEqual(ranked.count, 1)
    }

    func test_limitsTo30_whenMoreProvided() {
        let movers = (0..<50).map { mover("m\($0)", dayChange: Decimal($0) / 100) }

        let ranked = MoverRanking.rank(movers)

        XCTAssertEqual(ranked.count, 30)
    }

    func test_empty_returnsEmpty() {
        XCTAssertEqual(MoverRanking.rank([]).count, 0)
    }
}

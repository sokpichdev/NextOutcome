import XCTest
import MarketsDomain
@testable import MarketsData

final class MoverRankingTests: XCTestCase {
    private func mover(
        _ id: String,
        eventSlug: String? = nil,
        probability: Decimal = 0.5,
        dayChange: Decimal = 0.1,
        volume24h: Decimal = 100
    ) -> Mover {
        // Defaults each mover to its own event unless a shared slug is passed explicitly,
        // so ranking-order tests aren't accidentally collapsed by the one-per-event rule.
        Mover(id: id, question: id, eventSlug: eventSlug ?? "e-\(id)", eventTitle: id, imageURL: nil,
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
        let first = mover("dup", eventSlug: "e", dayChange: 0.4)
        let duplicate = mover("dup", eventSlug: "e", dayChange: 0.4)

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

    // MARK: - Same-event collapsing

    /// Regression test for the "GPT-5.6 released by July 7 / July 8" bug: an event with
    /// several sibling markets (different target dates) must collapse to a single row —
    /// the biggest mover of that event — rather than showing one row per sibling market.
    func test_collapsesSameEvent_toItsSingleBiggestMover() {
        let july7 = mover("july7", eventSlug: "gpt-5pt6-released-by", dayChange: -0.59)
        let july8 = mover("july8", eventSlug: "gpt-5pt6-released-by", dayChange: -0.55)
        let other = mover("other", eventSlug: "some-other-event", dayChange: 0.3)

        let ranked = MoverRanking.rank([july7, july8, other])

        XCTAssertEqual(ranked.count, 2)
        XCTAssertEqual(ranked.map(\.id), ["july7", "other"])
    }

    /// A genuinely distinct event whose question merely *reads* similarly (e.g. a separate
    /// duplicate-looking market on Polymarket with its own event id) is not collapsed — only
    /// markets sharing the same event id are, since the detail screen groups by event id.
    func test_distinctEvents_withSimilarQuestions_areNotCollapsed() {
        let a = mover("a", eventSlug: "event-a", dayChange: -0.4)
        let b = mover("b", eventSlug: "event-b", dayChange: -0.3)

        let ranked = MoverRanking.rank([a, b])

        XCTAssertEqual(ranked.count, 2)
    }

    /// When the biggest-mover title changes depending on the volume tiebreak, the event
    /// collapse still yields exactly one row per event id.
    func test_collapsesSameEvent_usingVolumeTiebreak_whenMagnitudeTied() {
        let lowVol = mover("low-vol", eventSlug: "same-event", dayChange: 0.3, volume24h: 10)
        let highVol = mover("high-vol", eventSlug: "same-event", dayChange: -0.3, volume24h: 999)

        let ranked = MoverRanking.rank([lowVol, highVol])

        XCTAssertEqual(ranked.map(\.id), ["high-vol"])
    }
}

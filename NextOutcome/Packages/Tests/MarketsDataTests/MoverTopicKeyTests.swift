import XCTest
@testable import MarketsData

final class MoverTopicKeyTests: XCTestCase {
    /// Regression test: these are two separate Polymarket *events* for the same real-world
    /// question, distinguished only by phrasing — the exact case the user reported still
    /// showing as duplicate Breaking rows after the same-event collapse.
    func test_sameSubjectAndDate_differentPhrasing_producesMatchingKey() {
        let a = MoverTopicKey.key(for: "GPT-5.6 released by July 7, 2026?")
        let b = MoverTopicKey.key(for: "Will GPT-5.6 be released on July 7, 2026?")

        XCTAssertNotNil(a)
        XCTAssertEqual(a, b)
    }

    func test_sameSubject_differentDate_producesDifferentKey() {
        let july7 = MoverTopicKey.key(for: "GPT-5.6 released by July 7, 2026?")
        let july8 = MoverTopicKey.key(for: "GPT-5.6 released by July 8, 2026?")

        XCTAssertNotEqual(july7, july8)
    }

    func test_noDateMentioned_returnsNil() {
        XCTAssertNil(MoverTopicKey.key(for: "Will Trump speak to Vladimir Putin in July?"))
    }

    func test_unrelatedQuestions_withDates_produceDistinctKeys() {
        let seoul = MoverTopicKey.key(for: "Will the lowest temperature in Seoul be 24°C on July 5?")
        let ethereum = MoverTopicKey.key(for: "Ethereum Up or Down on July 5?")

        XCTAssertNotNil(seoul)
        XCTAssertNotNil(ethereum)
        XCTAssertNotEqual(seoul, ethereum)
    }
}

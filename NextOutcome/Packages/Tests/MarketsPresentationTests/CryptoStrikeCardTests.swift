import XCTest
@testable import MarketsPresentation
import MarketsDomain

final class CryptoStrikeCardTests: XCTestCase {
    private func market(groupItemTitle: String?, question: String = "Q") -> Market {
        Market(
            id: "m1", question: question, slug: "m1", outcomes: [],
            volume: 0, liquidity: 0, endDate: nil, isResolved: false,
            imageURL: nil, groupItemTitle: groupItemTitle
        )
    }

    func test_rowLabel_aboveBelow_usesGroupItemTitleAsIs() {
        let label = CryptoStrikeCard.rowLabel(
            for: market(groupItemTitle: "52,000"), kind: .aboveBelow,
            eventTitle: "Bitcoin above ___ on July 10?"
        )
        XCTAssertEqual(label, "52,000")
    }

    func test_rowLabel_priceRange_usesGroupItemTitleAsIs() {
        let label = CryptoStrikeCard.rowLabel(
            for: market(groupItemTitle: "64,000-66,000"), kind: .priceRange,
            eventTitle: "Bitcoin price on July 10?"
        )
        XCTAssertEqual(label, "64,000-66,000")
    }

    func test_rowLabel_hitPrice_usesGroupItemTitleAsIs_realDataAlreadyEmbedsDirection() {
        // Real Gamma data embeds the per-row direction arrow directly in groupItemTitle
        // (e.g. "↑ 100,000" or "↓ 60,000"), and a single hitPrice event can mix both
        // directions across its rows (verified against the live API for "What price will
        // Bitcoin hit in 2026?"). The client must not re-derive or re-prepend a direction.
        let label = CryptoStrikeCard.rowLabel(
            for: market(groupItemTitle: "↑ 65,000"), kind: .hitPrice,
            eventTitle: "What price will Bitcoin hit in July?"
        )
        XCTAssertEqual(label, "↑ 65,000")
    }

    func test_rowLabel_hitPrice_doesNotAddASecondArrow_whenGroupItemTitleAlreadyHasOne() {
        let label = CryptoStrikeCard.rowLabel(
            for: market(groupItemTitle: "↓ 60,000"), kind: .hitPrice,
            eventTitle: "What price will Bitcoin hit in 2026?"
        )
        XCTAssertEqual(label, "↓ 60,000")
    }

    func test_rowLabel_fallsBackToQuestion_whenGroupItemTitleNil() {
        let label = CryptoStrikeCard.rowLabel(
            for: market(groupItemTitle: nil, question: "Some question"), kind: .aboveBelow,
            eventTitle: "Bitcoin above ___ on July 10?"
        )
        XCTAssertEqual(label, "Some question")
    }
}

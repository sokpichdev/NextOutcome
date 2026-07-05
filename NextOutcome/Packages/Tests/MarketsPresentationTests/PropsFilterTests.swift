//
//  PropsFilterTests.swift
//  NextOutcome
//

import XCTest
@testable import MarketsPresentation
import MarketsDomain

final class PropsFilterTests: XCTestCase {
    private func event(_ title: String, marketType: String? = nil) -> Event {
        let market = Market(
            id: "m", question: title, slug: "m", outcomes: [], volume: 0, liquidity: 0,
            endDate: nil, isResolved: false, imageURL: nil, sportsMarketType: marketType
        )
        return Event(id: "e", title: title, slug: "e", markets: [market], volume: 0, imageURL: nil)
    }

    func test_all_matchesEverything() {
        XCTAssertTrue(PropsFilter.all.matches(event("World Cup Winner")))
        XCTAssertTrue(PropsFilter.all.matches(event("Anything")))
    }

    func test_awards_matchesTitleKeywords() {
        XCTAssertTrue(PropsFilter.awards.matches(event("World Cup: Golden Boot Winner")))
        XCTAssertTrue(PropsFilter.awards.matches(event("World Cup: Golden Ball Winner")))
        XCTAssertFalse(PropsFilter.awards.matches(event("World Cup Winner")))
        XCTAssertFalse(PropsFilter.awards.matches(event("Group A Winner")))
    }

    func test_playerH2H_matchesH2HTitleOrPlayerMarkets() {
        XCTAssertTrue(PropsFilter.playerH2H.matches(event("World Cup Goals H2H: Messi vs. Ronaldo")))
        XCTAssertTrue(PropsFilter.playerH2H.matches(event("Brazil vs. Morocco - Player Props", marketType: "soccer_player_goals")))
        XCTAssertFalse(PropsFilter.playerH2H.matches(event("World Cup Winner")))
    }

    func test_groupFutures_matchesGroupTitles() {
        XCTAssertTrue(PropsFilter.groupFutures.matches(event("Will Haiti win Group C in the 2026 FIFA World Cup?")))
        XCTAssertTrue(PropsFilter.groupFutures.matches(event("World Cup: Group of Champion")))
        XCTAssertFalse(PropsFilter.groupFutures.matches(event("World Cup Winner")))
    }
}

//
//  FlagMarqueeTileTests.swift
//  NextOutcome
//

import XCTest
@testable import MarketsPresentation
import MarketsDomain

final class FlagMarqueeTileTests: XCTestCase {
    private func market(_ id: String, yes: Double, resolved: Bool = false, active: Bool = true) -> Market {
        Market(
            id: id, question: id, slug: id,
            outcomes: [Outcome(id: "\(id)-y", title: "Yes", price: Decimal(yes)),
                       Outcome(id: "\(id)-n", title: "No", price: Decimal(1 - yes))],
            volume: 0, liquidity: 0, endDate: nil, isResolved: resolved, isActive: active,
            imageURL: nil
        )
    }

    private func winner(_ markets: [Market]) -> Event {
        Event(id: "w", title: "World Cup Winner", slug: "world-cup-winner",
              markets: markets, volume: 0, imageURL: nil)
    }

    func test_captions_percentOutAndSubOnePercent() {
        let tiles = FlagMarqueeView.tiles(from: winner([
            market("france", yes: 0.35),
            market("longshot", yes: 0.004),
            market("algeria", yes: 0.0, resolved: true),
        ]))
        let byID = Dictionary(uniqueKeysWithValues: tiles.map { ($0.id, $0) })
        XCTAssertEqual(byID["france"]?.caption, "35%")
        XCTAssertEqual(byID["longshot"]?.caption, "<1%")
        XCTAssertEqual(byID["algeria"]?.caption, "OUT")
        XCTAssertEqual(byID["algeria"]?.isOut, true)
        XCTAssertEqual(byID["france"]?.isOut, false)
    }

    func test_inactivePlaceholders_dropped() {
        let tiles = FlagMarqueeView.tiles(from: winner([
            market("real", yes: 0.2),
            market("placeholder", yes: 0.0, active: false),
        ]))
        XCTAssertEqual(tiles.map(\.id), ["real"])
    }

    func test_outTiles_spreadAmongAliveTiles() {
        // 4 alive + 2 out should not leave the two OUT tiles adjacent at the end.
        let markets = [
            market("a1", yes: 0.30), market("a2", yes: 0.25),
            market("o1", yes: 0.0, resolved: true),
            market("a3", yes: 0.20), market("a4", yes: 0.15),
            market("o2", yes: 0.0, resolved: true),
        ]
        let tiles = FlagMarqueeView.tiles(from: winner(markets))
        let outPositions = tiles.enumerated().filter { $0.element.isOut }.map(\.offset)
        XCTAssertEqual(tiles.filter(\.isOut).count, 2)
        // The two OUT tiles are not both crammed into the final two slots.
        XCTAssertNotEqual(outPositions, [tiles.count - 2, tiles.count - 1])
    }
}

//
//  MapGlobeBuilderTests.swift
//  NextOutcome
//

import XCTest
@testable import MarketsPresentation
import MarketsDomain

final class MapGlobeBuilderTests: XCTestCase {
    private func market(_ id: String, country: String, yes: Double, active: Bool = true) -> Market {
        Market(id: id, question: country, slug: id,
               outcomes: [Outcome(id: "\(id)-y", title: "Yes", price: Decimal(yes)),
                          Outcome(id: "\(id)-n", title: "No", price: Decimal(1 - yes))],
               volume: 0, liquidity: 0, endDate: nil, isResolved: false, isActive: active,
               imageURL: nil, groupItemTitle: country)
    }

    private func winner(_ markets: [Market]) -> Event {
        Event(id: "w", title: "World Cup Winner", slug: "world-cup-winner",
              markets: markets, volume: 0, imageURL: nil)
    }

    func test_countries_keepOnlyKnownCoordinates_sortedByPercent() {
        let event = winner([
            market("m1", country: "Brazil", yes: 0.2),
            market("m2", country: "France", yes: 0.35),
            market("m3", country: "Neverland", yes: 0.9), // unknown coords → dropped
        ])
        let countries = MapGlobeBuilder.countries(from: event)
        XCTAssertEqual(countries.map(\.name), ["France", "Brazil"])
        XCTAssertEqual(countries.first?.percent ?? 0, 0.35, accuracy: 0.001)
    }

    func test_countries_useTeamAbbreviationWhenAvailable() {
        let teams = ["france": GameTeam(name: "France", abbreviation: "FRA", logoURL: nil,
                                        colorHex: "#0000ff", ordering: "")]
        let countries = MapGlobeBuilder.countries(from: winner([market("m", country: "France", yes: 0.3)]),
                                                   teams: teams)
        XCTAssertEqual(countries.first?.abbreviation, "FRA")
        XCTAssertEqual(countries.first?.colorHex, "#0000ff")
    }

    func test_caption_subOnePercent() {
        let countries = MapGlobeBuilder.countries(from: winner([market("m", country: "Egypt", yes: 0.004)]))
        XCTAssertEqual(countries.first?.caption, "<1%")
    }

    func test_inactiveMarkets_dropped() {
        let countries = MapGlobeBuilder.countries(from: winner([
            market("m", country: "Spain", yes: 0.0, active: false)
        ]))
        XCTAssertTrue(countries.isEmpty)
    }
}

//
//  BracketBuilderTests.swift
//  NextOutcome
//

import XCTest
@testable import MarketsPresentation
import MarketsDomain

final class BracketBuilderTests: XCTestCase {
    private func moneyline(_ id: String, team: String, yes: Double) -> Market {
        Market(id: id, question: team, slug: id,
               outcomes: [Outcome(id: "\(id)-y", title: "Yes", price: Decimal(yes)),
                          Outcome(id: "\(id)-n", title: "No", price: Decimal(1 - yes))],
               volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil,
               sportsMarketType: "moneyline", groupItemTitle: team)
    }

    private func game(_ id: String, home: String, away: String, homeYes: Double, awayYes: Double,
                      kickoff: Date = .init(timeIntervalSince1970: 1_782_216_000)) -> Event {
        Event(id: id, title: "\(home) vs. \(away)", slug: id,
              markets: [moneyline("\(id)-h", team: home, yes: homeYes),
                        moneyline("\(id)-d", team: "Draw (\(home) vs. \(away))", yes: 0.1),
                        moneyline("\(id)-a", team: away, yes: awayYes)],
              volume: 0, imageURL: nil, gameStartTime: kickoff)
    }

    private func advanceEvent() -> Event {
        Event(id: "adv", title: "World Cup: Nation To Reach Quarterfinals", slug: "adv",
              markets: [moneyline("m-fra", team: "France", yes: 0.93),
                        moneyline("m-mar", team: "Morocco", yes: 0.55),
                        moneyline("m-can", team: "Canada", yes: 0.28)],
              volume: 0, imageURL: nil)
    }

    func test_pages_orderAndTitles() {
        let pages = BracketBuilder.pages(
            games: [game("g1", home: "Paraguay", away: "France", homeYes: 0.08, awayYes: 0.93)],
            results: [:],
            props: [advanceEvent()]
        )
        XCTAssertEqual(pages.map(\.title), ["Groups", "Round of 16", "Quarter-finals", "Semi-finals", "Final"])
    }

    func test_advanceRows_sortedByChanceDescending() {
        let rows = BracketBuilder.advanceRows(from: advanceEvent())
        XCTAssertEqual(rows.map(\.name), ["France", "Morocco", "Canada"])
        XCTAssertEqual(rows.first?.percent ?? 0, 0.93, accuracy: 0.001)
    }

    func test_match_scheduled_carriesWinPercentNotScore() {
        let m = BracketBuilder.match(from: game("g1", home: "Paraguay", away: "France",
                                                homeYes: 0.08, awayYes: 0.93), result: nil)
        XCTAssertEqual(m?.status, .scheduled)
        XCTAssertEqual(m?.home?.name, "Paraguay")
        XCTAssertEqual(m?.away?.winPercent ?? 0, 0.93, accuracy: 0.001)
        XCTAssertNil(m?.home?.score)
    }

    func test_match_final_marksWinnerByScore() {
        let result = GameResult(
            eventID: "g1", score: "3-0", elapsed: nil, period: "FT", live: false, ended: true,
            teams: [GameTeam(name: "France", abbreviation: "FRA", logoURL: nil, colorHex: "#0000ff", ordering: "home"),
                    GameTeam(name: "Sweden", abbreviation: "SWE", logoURL: nil, colorHex: "#ffcc00", ordering: "away")]
        )
        let m = BracketBuilder.match(from: game("g1", home: "France", away: "Sweden",
                                                homeYes: 0.8, awayYes: 0.2), result: result)
        XCTAssertEqual(m?.status, .final)
        XCTAssertEqual(m?.home?.score, 3)
        XCTAssertEqual(m?.home?.isWinner, true)
        XCTAssertEqual(m?.away?.isWinner, false)
        XCTAssertNil(m?.home?.winPercent) // final games show score, not %
    }

    func test_pages_emptyWhenNoGamesOrAdvance() {
        XCTAssertTrue(BracketBuilder.pages(games: [], results: [:], props: []).allSatisfy {
            if case .placeholder = $0 { return true } else { return false }
        })
    }
}

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

    private func groupEvent(_ letter: String, teams: [String]) -> Event {
        Event(id: "grp-\(letter)", title: "World Cup Group \(letter.uppercased()) Winner",
              slug: "world-cup-group-\(letter)-winner",
              markets: (teams + ["Other"]).enumerated().map { moneyline("g\(letter)\($0.offset)", team: $0.element, yes: 0.25) },
              volume: 0, imageURL: nil)
    }

    func test_groupStandings_membershipAndAdvanceSorted() {
        let advance = Event(id: "adv", title: "World Cup: Nation To Reach Quarterfinals", slug: "adv",
                            markets: [moneyline("a1", team: "Mexico", yes: 0.9),
                                      moneyline("a2", team: "Czechia", yes: 0.1),
                                      moneyline("a3", team: "South Korea", yes: 0.4)],
                            volume: 0, imageURL: nil)
        let standings = BracketBuilder.groupStandings(
            groupEvents: [groupEvent("a", teams: ["Mexico", "South Africa", "South Korea", "Czechia"])],
            advanceEvent: advance
        )
        XCTAssertEqual(standings.count, 1)
        XCTAssertEqual(standings.first?.name, "Group A")
        // "Other" excluded; sorted by advance % desc (unknowns last).
        XCTAssertEqual(standings.first?.teams.map(\.name), ["Mexico", "South Korea", "Czechia", "South Africa"])
        XCTAssertEqual(standings.first?.teams.first?.advancePercent ?? 0, 0.9, accuracy: 0.001)
    }

    func test_groups_prefersStandings_overFlatBoard() {
        let advance = advanceEvent()
        let pages = BracketBuilder.pages(
            games: [], results: [:], props: [advance],
            groupEvents: [groupEvent("a", teams: ["France", "Morocco", "Canada", "Spain"])]
        )
        guard case .groups(let data) = pages.first else { return XCTFail("expected groups page") }
        XCTAssertFalse(data.standings.isEmpty)
    }

    private func resolvedGame(_ id: String, home: String, away: String, homeWon: Bool) -> Event {
        Event(id: id, title: "\(home) vs. \(away)", slug: id,
              markets: [Market(id: "\(id)-h", question: home, slug: "\(id)-h",
                               outcomes: [Outcome(id: "\(id)-hy", title: "Yes", price: homeWon ? 1 : 0),
                                          Outcome(id: "\(id)-hn", title: "No", price: homeWon ? 0 : 1)],
                               volume: 0, liquidity: 0, endDate: nil, isResolved: true, imageURL: nil,
                               sportsMarketType: "moneyline", groupItemTitle: home),
                        Market(id: "\(id)-a", question: away, slug: "\(id)-a",
                               outcomes: [Outcome(id: "\(id)-ay", title: "Yes", price: homeWon ? 0 : 1),
                                          Outcome(id: "\(id)-an", title: "No", price: homeWon ? 1 : 0)],
                               volume: 0, liquidity: 0, endDate: nil, isResolved: true, imageURL: nil,
                               sportsMarketType: "moneyline", groupItemTitle: away)],
              volume: 0, imageURL: nil, gameStartTime: Date(timeIntervalSince1970: 1_781_000_000))
    }

    func test_pages_includeRoundOf32_fromCompletedGames() {
        let pages = BracketBuilder.pages(
            games: [game("g1", home: "Paraguay", away: "France", homeYes: 0.08, awayYes: 0.93)],
            completedGames: [resolvedGame("c1", home: "France", away: "Sweden", homeWon: true)],
            results: [:],
            props: [advanceEvent()]
        )
        XCTAssertEqual(pages.map(\.title),
                       ["Groups", "Round of 32", "Round of 16", "Quarter-finals", "Semi-finals", "Final"])
    }

    func test_match_resolvedWithoutScore_marksWinnerFromMoneyline() {
        let m = BracketBuilder.match(from: resolvedGame("c1", home: "France", away: "Sweden", homeWon: true),
                                     result: nil)
        XCTAssertEqual(m?.status, .final)
        XCTAssertEqual(m?.home?.isWinner, true)
        XCTAssertEqual(m?.away?.isWinner, false)
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

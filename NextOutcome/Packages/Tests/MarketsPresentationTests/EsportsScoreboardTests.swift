//
//  EsportsScoreboardTests.swift
//  NextOutcome
//

import XCTest
import MarketsDomain
@testable import MarketsPresentation

final class EsportsScoreboardTests: XCTestCase {

    // MARK: - Fixtures

    /// A "Map N Winner" market. `homePrice` is the home team's outcome price, so 0.9995
    /// means home has taken the map.
    private func mapWinner(_ number: Int, homePrice: Double, resolved: Bool = false) -> Market {
        Market(
            id: "map\(number)", question: "Map \(number) Winner", slug: "map\(number)",
            outcomes: [Outcome(id: "h", title: "Eternal Fire Academy", price: Decimal(homePrice)),
                       Outcome(id: "a", title: "Vitality Academy", price: Decimal(1 - homePrice))],
            volume: 0, liquidity: 0, endDate: nil, isResolved: resolved, imageURL: nil,
            sportsMarketType: "child_moneyline", groupItemTitle: "Map \(number) Winner"
        )
    }

    private func event(markets: [Market]) -> Event {
        Event(id: "e", title: "Counter-Strike: Eternal Fire Academy vs Vitality Academy (BO3)",
              slug: "e", markets: markets, volume: 0, imageURL: nil)
    }

    private func result(score: String?, period: String?, live: Bool = true, ended: Bool = false,
                        teams: Bool = true) -> GameResult {
        GameResult(
            eventID: "e", score: score, elapsed: nil, period: period, live: live, ended: ended,
            teams: teams
                ? [GameTeam(name: "Eternal Fire Academy", abbreviation: "EFA", logoURL: nil,
                            colorHex: "#29447c", ordering: "home"),
                   GameTeam(name: "Vitality Academy", abbreviation: "VITA", logoURL: nil,
                            colorHex: "#ffff00", ordering: "away")]
                : []
        )
    }

    private func build(_ markets: [Market], _ result: GameResult?) -> EsportsScoreboardBuilder.Model {
        EsportsScoreboardBuilder.build(event: event(markets: markets), result: result)
    }

    // MARK: - Tests

    func test_liveBo3_marksFinishedMapsAndScoresTheOneInPlay() {
        // The screenshot case: home took map 1, away took map 2, map 3 is being played.
        let model = build(
            [mapWinner(1, homePrice: 0.9995), mapWinner(2, homePrice: 0.0005), mapWinner(3, homePrice: 0.5)],
            result(score: "7-5|1-1|Bo3", period: "3/3")
        )
        XCTAssertEqual(model.columns.map(\.state), [.won(.home), .won(.away), .inProgress(home: 7, away: 5)])
        XCTAssertEqual(model.home.mapsWon, 1)
        XCTAssertEqual(model.away.mapsWon, 1)
        XCTAssertEqual(model.seriesLine, "1 – 1 · Bo3")
    }

    func test_aMapSettlesOnPriceBeforeTheResolvedFlagFlips() {
        // Gamma had Map 1 Winner at 0.9995/0.0005 while the event was still open. Waiting
        // for `isResolved` would leave a decided map reading as unplayed all series.
        let model = build([mapWinner(1, homePrice: 0.9995, resolved: false)],
                          result(score: "0-0|1-0|Bo3", period: "2/3"))
        XCTAssertEqual(model.columns.first?.state, .won(.home))
    }

    func test_decidedSeries_voidsTheMapThatWillNeverBePlayed() {
        // After a 2-0 Bo3, Gamma leaves "Map 3 Winner" open at 0.5/0.5. Showing that as
        // upcoming would promise a map nobody will play.
        let model = build(
            [mapWinner(1, homePrice: 0.9995), mapWinner(2, homePrice: 0.9995), mapWinner(3, homePrice: 0.5)],
            result(score: "000-000|2-0|Bo3", period: "2/3", live: false, ended: true)
        )
        XCTAssertEqual(model.columns.map(\.state), [.won(.home), .won(.home), .void])
    }

    func test_playedMapIsMarkedFromTheSeriesScoreWhenNoMapMarketExists() {
        // The live Dota case: no "Map N Winner" markets at all, but a series score of 0–1
        // on map 2 says plainly that away took map 1.
        let model = build([], result(score: "000-000|0-1|Bo3", period: "2/3"))
        XCTAssertEqual(model.columns[0].state, .won(.away))
        XCTAssertEqual(model.columns[1].state, .inProgress(home: 0, away: 0))
        XCTAssertEqual(model.columns[2].state, .unplayed)
    }

    func test_ambiguousSeriesLeavesPlayedMapsBlankRatherThanGuessing() {
        // At 1–1 both maps are done, but nothing says which side won which. Picking an
        // order would be inventing a result.
        let model = build([], result(score: "3-2|1-1|Bo3", period: "3/3"))
        XCTAssertEqual(model.columns[0].state, .unplayed)
        XCTAssertEqual(model.columns[1].state, .unplayed)
        XCTAssertEqual(model.columns[2].state, .inProgress(home: 3, away: 2))
    }

    func test_mapMarketWinsOverTheInferredResult() {
        // Where a map market exists it's authoritative — inference is only the fallback.
        let model = build([mapWinner(1, homePrice: 0.9995)],
                          result(score: "000-000|1-0|Bo3", period: "2/3"))
        XCTAssertEqual(model.columns[0].state, .won(.home))
    }

    func test_bo1_rendersASingleColumn() {
        let model = build([mapWinner(1, homePrice: 0.5)], result(score: "9-4|0-0|Bo1", period: "1/1"))
        XCTAssertEqual(model.columns.count, 1)
        XCTAssertEqual(model.columns.first?.state, .inProgress(home: 9, away: 4))
    }

    func test_bo5_rendersFiveColumns() {
        let model = build([mapWinner(1, homePrice: 0.9995)],
                          result(score: "0-0|1-0|Bo5", period: "2/5"))
        XCTAssertEqual(model.columns.count, 5)
        XCTAssertEqual(model.columns.map(\.number), [1, 2, 3, 4, 5])
        XCTAssertEqual(model.columns[3].state, .unplayed)
    }

    func test_upcomingMatch_withNoResultAtAll() {
        let model = build([mapWinner(1, homePrice: 0.5), mapWinner(2, homePrice: 0.5)], nil)
        // No period and no score, so the map markets are the only source of a column count.
        XCTAssertEqual(model.columns.count, 2)
        XCTAssertEqual(model.columns.map(\.state), [.unplayed, .unplayed])
        XCTAssertNil(model.seriesLine)
    }

    func test_noMarketsAndNoResult_stillRendersOneColumn() {
        // The range 1...total would trap on a zero count.
        let model = build([], nil)
        XCTAssertEqual(model.columns.count, 1)
        XCTAssertEqual(model.columns.first?.state, .unplayed)
    }

    func test_resultWithoutTeams_fallsBackToTheParsedTitle() {
        let model = build([], result(score: "0-0|1-0|Bo3", period: "2/3", teams: false))
        XCTAssertEqual(model.home.name, "Eternal Fire Academy")
        XCTAssertEqual(model.away.name, "Vitality Academy")
        XCTAssertNil(model.home.logoURL)
    }

    func test_teamsSupplyLogosAndBrandColours() {
        let model = build([], result(score: "0-0|0-0|Bo3", period: "1/3"))
        XCTAssertEqual(model.home.colorHex, "#29447c")
        XCTAssertEqual(model.away.colorHex, "#ffff00")
    }

    func test_unparseableScore_hidesTheSeriesLineWithoutCrashing() {
        let model = build([mapWinner(1, homePrice: 0.9995)], result(score: "live", period: "2/3"))
        XCTAssertNil(model.seriesLine)
        XCTAssertNil(model.home.mapsWon)
        // The map markets still settle their columns.
        XCTAssertEqual(model.columns.first?.state, .won(.home))
    }

    func test_currentMapWithNoScore_readsAsUnplayedRatherThanZeroZero() {
        // Never render an observed-looking 0-0 for a score we don't actually have.
        let model = build([], GameResult(eventID: "e", score: nil, elapsed: nil, period: "2/3",
                                         live: true, ended: false, teams: []))
        XCTAssertEqual(model.columns[1].state, .unplayed)
    }

    func test_endedMatch_neverShowsAMapAsInProgress() {
        let model = build([], result(score: "16-14|2-1|Bo3", period: "3/3", live: false, ended: true))
        XCTAssertFalse(model.columns.contains { if case .inProgress = $0.state { return true } else { return false } })
    }
}

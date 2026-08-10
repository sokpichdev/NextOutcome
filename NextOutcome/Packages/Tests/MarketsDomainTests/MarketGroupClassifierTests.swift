import XCTest
@testable import MarketsDomain

final class MarketGroupClassifierTests: XCTestCase {
    func testMoneylineViaSportsMarketType() {
        let m = Market.fixture(sportsMarketType: "moneyline")
        XCTAssertEqual(MarketGroupClassifier.groups(for: [m]).first?.group, .moneyline)
    }

    func testTotalsViaSportsMarketTypeWithOUTitle() {
        let m = Market.fixture(question: "O/U 2.5", sportsMarketType: "totals")
        XCTAssertEqual(MarketGroupClassifier.groups(for: [m]).first?.group, .totals)
    }

    func testBothTeamsToScoreViaQuestion() {
        let m = Market.fixture(question: "Will both teams to score?", sportsMarketType: nil)
        XCTAssertEqual(MarketGroupClassifier.groups(for: [m]).first?.group, .bothTeamsToScore)
    }

    func testFirstTeamToScoreViaGroupItemTitle() {
        let m = Market.fixture(question: "Who scores first?", sportsMarketType: nil, groupItemTitle: "First Team to Score")
        XCTAssertEqual(MarketGroupClassifier.groups(for: [m]).first?.group, .firstToScore)
    }

    func testTeamTotalsViaQuestion() {
        let m = Market.fixture(question: "Spain Totals", sportsMarketType: nil)
        XCTAssertEqual(MarketGroupClassifier.groups(for: [m]).first?.group, .teamTotals)
    }

    func testExtraTimeViaQuestion() {
        let m = Market.fixture(question: "Winner after Extra Time?", sportsMarketType: nil)
        XCTAssertEqual(MarketGroupClassifier.groups(for: [m]).first?.group, .extraTime)
    }

    func testPenaltyShootoutViaQuestion() {
        let m = Market.fixture(question: "Winner via Penalty Shootout?", sportsMarketType: nil)
        XCTAssertEqual(MarketGroupClassifier.groups(for: [m]).first?.group, .penaltyShootout)
    }

    func testUnknownFallsToOther() {
        let m = Market.fixture(question: "Will it rain?", sportsMarketType: nil)
        XCTAssertEqual(MarketGroupClassifier.groups(for: [m]).first?.group, .other)
    }

    func testSectionOrderIsStable() {
        let ms = [Market.fixture(sportsMarketType: "totals"), Market.fixture(sportsMarketType: "moneyline")]
        XCTAssertEqual(MarketGroupClassifier.groups(for: ms).map(\.group), [.moneyline, .totals])
    }

    func testMarketsSortedByYesProbabilityDescending() {
        // Real contenders lead; unpriced placeholder markets ("Team A" at 0) sink.
        let ms = [
            Market.fixture(id: "placeholder", groupItemTitle: "Team AO"),          // no price → 0
            Market.fixture(id: "france", groupItemTitle: "France", yesPrice: 0.34),
            Market.fixture(id: "argentina", groupItemTitle: "Argentina", yesPrice: 0.19),
        ]
        let markets = MarketGroupClassifier.groups(for: ms).first?.markets ?? []
        XCTAssertEqual(markets.map(\.id), ["france", "argentina", "placeholder"])
    }

    func testEmptyGroupsOmitted() {
        let ms = [Market.fixture(sportsMarketType: "moneyline")]
        let groups = MarketGroupClassifier.groups(for: ms)
        XCTAssertEqual(groups.count, 1)
        XCTAssertFalse(groups.contains { $0.group == .spreads })
    }

    func testTitles() {
        XCTAssertEqual(MarketGroup.moneyline.title, "Moneyline")
        XCTAssertEqual(MarketGroup.spreads.title, "Spreads")
        XCTAssertEqual(MarketGroup.totals.title, "Totals")
        XCTAssertEqual(MarketGroup.bothTeamsToScore.title, "Both Teams to Score")
        XCTAssertEqual(MarketGroup.firstToScore.title, "First Team to Score")
        XCTAssertEqual(MarketGroup.teamTotals.title, "Team Totals")
        XCTAssertEqual(MarketGroup.extraTime.title, "Extra Time")
        XCTAssertEqual(MarketGroup.penaltyShootout.title, "Penalty Shootout")
        XCTAssertEqual(MarketGroup.other.title, "Other")
        XCTAssertEqual(MarketGroup.mapWinner.title, "Map Winners")
        XCTAssertEqual(MarketGroup.mapHandicap.title, "Map Handicap")
        XCTAssertEqual(MarketGroup.mapTotals.title, "Map Rounds")
        XCTAssertEqual(MarketGroup.mapRoundHandicap.title, "Map Round Handicap")
    }

    // MARK: - Esports

    func testEsportsSportsMarketTypes() {
        // The four keys a Counter-Strike / LoL / Dota event actually sends. Before these
        // were classified, every one of them landed in "Other".
        XCTAssertEqual(group(for: Market.fixture(sportsMarketType: "child_moneyline")), .mapWinner)
        XCTAssertEqual(group(for: Market.fixture(sportsMarketType: "map_handicap")), .mapHandicap)
        XCTAssertEqual(group(for: Market.fixture(sportsMarketType: "round_over_under_game_1")), .mapTotals)
        XCTAssertEqual(group(for: Market.fixture(sportsMarketType: "round_handicap_game_2")), .mapRoundHandicap)
    }

    func testRoundMarketsMatchByPrefixSoLongSeriesStillClassify() {
        // A Bo5's map 4 and 5 markets must not fall into "Other" just because the suffix
        // wasn't in an exhaustive list.
        XCTAssertEqual(group(for: Market.fixture(sportsMarketType: "round_over_under_game_5")), .mapTotals)
        XCTAssertEqual(group(for: Market.fixture(sportsMarketType: "round_handicap_game_4")), .mapRoundHandicap)
    }

    func testEsportsSectionOrder() {
        let ms = [
            Market.fixture(id: "rh", sportsMarketType: "round_handicap_game_1"),
            Market.fixture(id: "ou", sportsMarketType: "round_over_under_game_1"),
            Market.fixture(id: "tot", sportsMarketType: "totals"),
            Market.fixture(id: "mh", sportsMarketType: "map_handicap"),
            Market.fixture(id: "map", sportsMarketType: "child_moneyline"),
            Market.fixture(id: "ml", sportsMarketType: "moneyline"),
        ]
        XCTAssertEqual(
            MarketGroupClassifier.groups(for: ms).map(\.group),
            [.moneyline, .mapWinner, .mapHandicap, .totals, .mapTotals, .mapRoundHandicap]
        )
    }

    func testMapSectionsOrderByMapNumberNotPrice() {
        // Map winners are played in sequence, so they read in sequence — and a settled map
        // priced at ~1.0 must not jump above the map being played.
        let ms = [
            Market.fixture(id: "m3", sportsMarketType: "child_moneyline", groupItemTitle: "Map 3 Winner", yesPrice: 0.5),
            Market.fixture(id: "m1", sportsMarketType: "child_moneyline", groupItemTitle: "Map 1 Winner", yesPrice: 0.9995),
            Market.fixture(id: "m2", sportsMarketType: "child_moneyline", groupItemTitle: "Map 2 Winner", yesPrice: 0.0005),
        ]
        XCTAssertEqual(MarketGroupClassifier.groups(for: ms).first?.markets.map(\.id), ["m1", "m2", "m3"])
    }

    func testUnpricedMapMarketsKeepAStableOrder() {
        // Every esports market reads price 0 through the Yes side, and `sorted` is unstable:
        // without the map-number key these rows shuffled between redraws.
        let ms = [
            Market.fixture(id: "c", sportsMarketType: "round_over_under_game_3"),
            Market.fixture(id: "a", sportsMarketType: "round_over_under_game_1"),
            Market.fixture(id: "b", sportsMarketType: "round_over_under_game_2"),
        ]
        for _ in 0..<20 {
            XCTAssertEqual(MarketGroupClassifier.groups(for: ms).first?.markets.map(\.id), ["a", "b", "c"])
        }
    }

    func testMapNumber() {
        // Preferred source: the trailing number on the sportsMarketType.
        XCTAssertEqual(MarketGroupClassifier.mapNumber(for: .fixture(sportsMarketType: "round_over_under_game_2")), 2)
        // child_moneyline carries no number, so the label is the only place the map is named.
        XCTAssertEqual(MarketGroupClassifier.mapNumber(
            for: .fixture(sportsMarketType: "child_moneyline", groupItemTitle: "Map 3 Winner")), 3)
        XCTAssertEqual(MarketGroupClassifier.mapNumber(
            for: .fixture(question: "Map 1 Total Rounds: Over/Under 21.5", sportsMarketType: nil)), 1)
        XCTAssertNil(MarketGroupClassifier.mapNumber(for: .fixture(sportsMarketType: "moneyline")))
        XCTAssertNil(MarketGroupClassifier.mapNumber(for: .fixture(question: "Match Winner", sportsMarketType: nil)))
    }

    /// The single group a lone market classifies into.
    private func group(for market: Market) -> MarketGroup? {
        MarketGroupClassifier.groups(for: [market]).first?.group
    }
}

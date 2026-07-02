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
    }
}

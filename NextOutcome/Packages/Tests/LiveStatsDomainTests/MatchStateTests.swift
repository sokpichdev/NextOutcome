import XCTest
@testable import LiveStatsDomain

final class MatchStateTests: XCTestCase {
    func testParseScoreSplitsHomeAway() {
        let s = MatchState.parseScore("127-132")
        XCTAssertEqual(s?.home, 127)
        XCTAssertEqual(s?.away, 132)
    }

    func testParseScoreEqualScore() {
        XCTAssertEqual(MatchState.parseScore("156-156")?.home, 156)
    }

    func testParseScoreRejectsGarbage() {
        XCTAssertNil(MatchState.parseScore("TBD"))
        XCTAssertNil(MatchState.parseScore(nil))
        XCTAssertNil(MatchState.parseScore("1-2-3"))
    }

    func testRichSectionsDefaultToNil() {
        let m = MatchState(gameID: "g")
        XCTAssertNil(m.lineups)
        XCTAssertNil(m.commentary)
        XCTAssertNil(m.ballPositionPct)
        XCTAssertTrue(m.events.isEmpty)
        XCTAssertEqual(m.home.goals, 0)
    }
}

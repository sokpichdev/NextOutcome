import XCTest
@testable import LiveStatsData
import LiveStatsDomain

/// Fixtures are verbatim frames captured off `wss://sports-api.polymarket.com/ws` on
/// 2026-07-03 (see `scripts/capture_sports_ws.py`). The live feed delivers only
/// score/period/live/ended snapshots — richer sections are absent by design.
final class SportsFrameDecodingTests: XCTestCase {
    private func decode(_ json: String) throws -> SportsFrameDTO {
        try JSONDecoder().decode(SportsFrameDTO.self, from: Data(json.utf8))
    }

    // Real captured "scheduled" frame.
    private let scheduledFrame = #"{"metadataGameId":"id2705202672147940","leagueAbbreviation":"cricket","score":"156-156","period":"Scheduled","live":false,"ended":false}"#
    // Real captured "full time" frame.
    private let endedFrame = #"{"metadataGameId":"id2704029570673024","leagueAbbreviation":"cricket","score":"127-132","period":"FT","live":false,"ended":true,"finishedTimestamp":"2026-07-03T05:32:36.167691882Z"}"#

    func testDecodesScheduledFrameFields() throws {
        let dto = try decode(scheduledFrame)
        XCTAssertEqual(dto.metadataGameId, "id2705202672147940")
        XCTAssertEqual(dto.leagueAbbreviation, "cricket")
        XCTAssertEqual(dto.score, "156-156")
        XCTAssertEqual(dto.period, "Scheduled")
        XCTAssertEqual(dto.live, false)
        XCTAssertEqual(dto.ended, false)
    }

    func testMapsScoreIntoTeamGoals() throws {
        let state = try decode(endedFrame).toMatchState(previous: nil)
        XCTAssertEqual(state?.gameID, "id2704029570673024")
        XCTAssertEqual(state?.home.goals, 127)
        XCTAssertEqual(state?.away.goals, 132)
        XCTAssertEqual(state?.period, "FT")
        XCTAssertEqual(state?.ended, true)
        XCTAssertEqual(state?.isLive, false)
        XCTAssertEqual(state?.league, "cricket")
    }

    func testUnpopulatedSectionsStayNil() throws {
        let state = try decode(scheduledFrame).toMatchState(previous: nil)
        XCTAssertNil(state?.lineups)
        XCTAssertNil(state?.commentary)
        XCTAssertNil(state?.ballPositionPct)
        XCTAssertNil(state?.home.shotsOn)
    }

    func testFrameWithoutGameIdIsSkipped() throws {
        let dto = try decode(#"{"leagueAbbreviation":"cricket"}"#)
        XCTAssertNil(dto.toMatchState(previous: nil))
    }

    func testUnknownFieldsDecodeTolerantly() throws {
        let dto = try decode(#"{"metadataGameId":"idX","mystery":42,"score":"1-0"}"#)
        XCTAssertEqual(dto.metadataGameId, "idX")
        XCTAssertEqual(dto.toMatchState(previous: nil)?.home.goals, 1)
    }
}

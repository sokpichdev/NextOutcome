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

    // MARK: - Esports frames

    // Real captured esports frame. Note it names its id `gameId` and sends it as a number,
    // where every other sport sends a `metadataGameId` string.
    private let esportsFrame = #"{"gameId":1616952,"leagueAbbreviation":"cs2","homeTeam":"Eternal Fire Academy","awayTeam":"Vitality Academy","status":"running","score":"000-000|1-1|Bo3","period":"3/3","live":true,"ended":false}"#

    func testEsportsFrameIsIdentifiedByItsNumericGameId() throws {
        // Before this, every esports frame decoded with a nil identifier and was dropped,
        // so the esports live socket delivered nothing at all.
        let dto = try decode(esportsFrame)
        XCTAssertNil(dto.metadataGameId)
        XCTAssertEqual(dto.gameId, 1_616_952)
        XCTAssertEqual(dto.identifier, "1616952")
        XCTAssertEqual(dto.toMatchState(previous: nil)?.gameID, "1616952")
    }

    func testEsportsCompositeScoreSurvivesAsRawScore() throws {
        // "000-000|1-1|Bo3" isn't a home-away pair, so goal parsing declines it — but the
        // raw string has to reach the consumer that knows how to read maps out of it.
        let state = try decode(esportsFrame).toMatchState(previous: nil)
        XCTAssertEqual(state?.rawScore, "000-000|1-1|Bo3")
        XCTAssertEqual(state?.home.goals, 0)
        XCTAssertEqual(state?.period, "3/3")
        XCTAssertEqual(state?.isLive, true)
    }

    func testMetadataGameIdWinsWhenBothArePresent() throws {
        let dto = try decode(#"{"metadataGameId":"idX","gameId":99,"score":"1-0"}"#)
        XCTAssertEqual(dto.identifier, "idX")
    }

    func testFrameWithNeitherIdentifierIsStillSkipped() throws {
        let dto = try decode(#"{"leagueAbbreviation":"cs2","score":"1-0"}"#)
        XCTAssertNil(dto.identifier)
        XCTAssertNil(dto.toMatchState(previous: nil))
    }
}

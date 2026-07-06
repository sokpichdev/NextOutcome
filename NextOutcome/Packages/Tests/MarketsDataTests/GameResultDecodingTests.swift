//
//  GameResultDecodingTests.swift
//  NextOutcome
//

import XCTest
@testable import MarketsData
import MarketsDomain

final class GameResultDecodingTests: XCTestCase {
    // Trimmed from a live `/events/results?id=640364` capture (2026-07-04).
    private let finishedJSON = Data("""
    [{"id":"640364","score":"3-2","elapsed":"","period":"VFT","live":false,"ended":true,
      "finishedTimestamp":"2026-07-04T00:45:12.218814Z",
      "teams":[
        {"id":3270232,"name":"Argentina","record":"","logo":"https://example.com/Argentina.png","abbreviation":"arg","color":"#67A4DC","ordering":"home"},
        {"id":3270263,"name":"Cabo Verde","logo":"https://example.com/Cabo Verde-eaec.png","abbreviation":"cvi","color":"#164a9c","ordering":"away"}
      ]}]
    """.utf8)

    func test_decode_finishedGame() throws {
        let dtos = try JSONDecoder().decode([GameResultDTO].self, from: finishedJSON)
        let result = try XCTUnwrap(dtos.first).toDomain(fallbackEventID: "fallback")

        XCTAssertEqual(result.eventID, "640364")
        XCTAssertEqual(result.score, "3-2")
        XCTAssertEqual(result.homeScore, 3)
        XCTAssertEqual(result.awayScore, 2)
        XCTAssertNil(result.elapsed) // empty string degrades to nil
        XCTAssertEqual(result.period, "VFT")
        XCTAssertFalse(result.live)
        XCTAssertTrue(result.ended)
        XCTAssertEqual(result.homeTeam?.name, "Argentina")
        XCTAssertEqual(result.homeTeam?.abbreviation, "ARG")
        XCTAssertEqual(result.awayTeam?.name, "Cabo Verde")
        XCTAssertNotNil(result.awayTeam?.logoURL) // space in URL percent-encoded
    }

    func test_decode_missingFieldsDegrade() throws {
        let json = Data(#"[{"live":true}]"#.utf8)
        let dtos = try JSONDecoder().decode([GameResultDTO].self, from: json)
        let result = try XCTUnwrap(dtos.first).toDomain(fallbackEventID: "e9")

        XCTAssertEqual(result.eventID, "e9") // falls back to the requested id
        XCTAssertNil(result.score)
        XCTAssertNil(result.homeScore)
        XCTAssertTrue(result.live)
        XCTAssertFalse(result.ended)
        XCTAssertTrue(result.teams.isEmpty)
    }

    func test_scoreParsing_rejectsMalformed() throws {
        let json = Data(#"[{"id":"1","score":"abandoned"}]"#.utf8)
        let result = try XCTUnwrap(JSONDecoder().decode([GameResultDTO].self, from: json).first)
            .toDomain(fallbackEventID: "1")
        XCTAssertEqual(result.score, "abandoned")
        XCTAssertNil(result.homeScore)
        XCTAssertNil(result.awayScore)
    }

    func test_decode_recordDegradesEmptyStringToNil() throws {
        let dtos = try JSONDecoder().decode([GameResultDTO].self, from: finishedJSON)
        let result = try XCTUnwrap(dtos.first).toDomain(fallbackEventID: "fallback")
        XCTAssertNil(result.homeTeam?.record) // "" degrades to nil
    }

    func test_decode_recordKeepsNonEmptyValue() throws {
        let json = Data("""
        [{"id":"1","teams":[{"name":"Max Holloway","record":"27-9-0","ordering":"home"}]}]
        """.utf8)
        let dtos = try JSONDecoder().decode([GameResultDTO].self, from: json)
        let result = try XCTUnwrap(dtos.first).toDomain(fallbackEventID: "e1")
        XCTAssertEqual(result.homeTeam?.record, "27-9-0")
    }
}

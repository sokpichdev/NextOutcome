//
//  SportsSummaryDecodingTests.swift
//  NextOutcome
//
//  Created by Sok Pich on 16/08/2026.
//

import XCTest
@testable import MarketsData

final class SportsSummaryDecodingTests: XCTestCase {
    /// Verbatim rows from `GET /sports/summary`, captured 2026-08-16. Note the shape: a
    /// dictionary keyed by league slug, not an array — nothing else in this API does that.
    private let payload = Data("""
    {"leagues": {
      "mlb": {
        "name": "MLB",
        "image": "https://polymarket-upload.s3.us-east-2.amazonaws.com/league-icons/mlb.png",
        "activeEventCount": 118, "hasLive": true,
        "eventDates": ["2026-08-16", "2026-08-17"],
        "earliestOpenDate": "2026-08-15", "volume": 5957601.5},
      "abb": {
        "name": "Big Bash League",
        "image": "https://polymarket-upload.s3.us-east-2.amazonaws.com/big-bash.png",
        "activeEventCount": 0, "hasLive": false, "volume": 0}
    }}
    """.utf8)

    private func decoded() throws -> SportsSummaryDTO {
        try JSONDecoder().decode(SportsSummaryDTO.self, from: payload)
    }

    func test_decodesDictionaryKeyedByLeagueSlug() throws {
        let mlb = try XCTUnwrap(decoded().leagues["mlb"])

        XCTAssertEqual(mlb.name, "MLB")
        XCTAssertEqual(mlb.activeEventCount, 118)
        XCTAssertEqual(mlb.hasLive, true)
        XCTAssertEqual(mlb.volume, 5957601.5)
        XCTAssertEqual(mlb.eventDates, ["2026-08-16", "2026-08-17"])
        XCTAssertEqual(mlb.earliestOpenDate, "2026-08-15")
    }

    func test_outOfSeasonRowOmitsDateFields() throws {
        // Real rows for dormant leagues drop `eventDates` and `earliestOpenDate` entirely
        // rather than sending null or []. Decoding must not require them.
        let abb = try XCTUnwrap(decoded().leagues["abb"])

        XCTAssertNil(abb.eventDates)
        XCTAssertNil(abb.earliestOpenDate)
        XCTAssertEqual(abb.activeEventCount, 0)
        XCTAssertEqual(abb.hasLive, false)
    }
}

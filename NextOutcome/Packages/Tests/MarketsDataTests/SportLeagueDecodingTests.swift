//
//  SportLeagueDecodingTests.swift
//  NextOutcome
//

import XCTest
@testable import MarketsData

final class SportLeagueDecodingTests: XCTestCase {
    /// Verbatim rows from `GET /sports`, captured 2026-08-09.
    private let payload = Data("""
    [
      {"id": 37, "sport": "cs2", "name": "CS2",
       "image": "https://polymarket-upload.s3.us-east-2.amazonaws.com/league-icons/cs2.png",
       "resolution": "https://www.hltv.org/", "ordering": "away",
       "tags": "1,100639,64,100780", "primaryTagId": 100780, "series": "10310"},
      {"id": 630, "sport": "ufl", "name": "UFL",
       "image": "https://polymarket-upload.s3.us-east-2.amazonaws.com/league-icons/ufl.png",
       "tags": "1,100639,1186,105925", "primaryTagId": 105925, "series": "12553"},
      {"id": 999, "sport": "mystery", "name": "Mystery", "tags": "64"}
    ]
    """.utf8)

    private func decoded() throws -> [SportLeagueDTO] {
        try JSONDecoder().decode([SportLeagueDTO].self, from: payload)
    }

    func test_decodesCatalogueRow() throws {
        let cs2 = try XCTUnwrap(decoded().first)
        let league = try XCTUnwrap(cs2.toDomain())

        XCTAssertEqual(league.id, "cs2")
        XCTAssertEqual(league.name, "CS2")
        // Numeric on the wire, a string in the domain — event tag ids are strings.
        XCTAssertEqual(league.primaryTagID, "100780")
        XCTAssertEqual(league.seriesID, "10310")
        XCTAssertEqual(league.iconURL?.lastPathComponent, "cs2.png")
    }

    func test_tagsFieldIsCommaSeparatedString_notAnArray() throws {
        // The whole esports scoping hangs off this: `"1,100639,64,100780"`, not `[1,100639,…]`.
        let rows = try decoded()
        XCTAssertEqual(rows[0].tagIDs, ["1", "100639", "64", "100780"])
        XCTAssertTrue(rows[0].tagIDs.contains("64"))
        XCTAssertFalse(rows[1].tagIDs.contains("64"))   // UFL is a traditional sport
    }

    func test_rowWithoutPrimaryTagIsDropped() throws {
        // Without a primary tag there is nothing to classify events against, so the tile
        // would be inert — better absent than dead.
        let mystery = try XCTUnwrap(decoded().last)
        XCTAssertNil(mystery.toDomain())
    }
}

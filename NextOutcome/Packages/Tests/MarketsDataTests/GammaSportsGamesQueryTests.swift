//
//  GammaSportsGamesQueryTests.swift
//  NextOutcome
//
//  Created by Sok Pich on 16/08/2026.
//

import XCTest
import Foundation
@testable import MarketsData
import MarketsDomain

/// The Sports hub's games query. The hub used to read the general sports tag sorted by 24h
/// volume, which is dominated by futures — measured against the live API, 20 fetched events
/// yielded 4 non-esports games and none in play. These params move both filters server-side.
final class GammaSportsGamesQueryTests: XCTestCase {
    /// The dictionary half of the query; the repeated-key half is asserted separately.
    private func params(live: Bool = false, startingAfter: Date? = nil, cursor: String? = nil) -> [String: String] {
        GammaEventQuery.sportsGamesParams(live: live, startingAfter: startingAfter, cursor: cursor).query
    }

    func test_scopesToGamesAndExcludesEsports() {
        // Tag 100639 is Gamma's "Games" tag — the one real fixtures carry. Excluding 64 keeps
        // esports out server-side, matching the chip row, which already filters it.
        XCTAssertEqual(params()["tag_id"], "100639")
        XCTAssertEqual(params()["exclude_tag_id"], "64")
    }

    func test_liveQueryAsksForInPlayGamesOnly() {
        XCTAssertEqual(params(live: true)["live"], "true")
    }

    func test_upcomingQueryOmitsTheLiveFlagEntirely() {
        // Sending `live=false` would exclude in-play games from the upcoming feed rather than
        // simply not filtering, so the flag must be absent.
        XCTAssertNil(params(live: false)["live"])
    }

    func test_startingAfterIsSentAsAnRFC3339StartTimeBound() {
        let date = Date(timeIntervalSince1970: 1_786_968_000)

        XCTAssertEqual(params(startingAfter: date)["start_time_min"], "2026-08-17T12:00:00Z")
    }

    func test_upcomingGamesAreOrderedByKickoffAscending() {
        XCTAssertEqual(params(startingAfter: Date())["order"], "startTime")
        XCTAssertEqual(params(startingAfter: Date())["ascending"], "true")
    }

    func test_leagueScopeIsAndedOntoTheGamesTagAsARepeatedItem() {
        // `tag_id` takes a single integer — a comma list is rejected outright — so Gamma ANDs
        // tags by repeating the key, which only works alongside `tag_match=all`.
        let scoped = GammaEventQuery.sportsGamesParams(
            live: false, startingAfter: nil, cursor: nil, leagueTagID: "100350"
        )

        XCTAssertEqual(scoped.query["tag_id"], "100639", "the Games tag stays in the dictionary")
        XCTAssertEqual(scoped.query["tag_match"], "all")
        XCTAssertEqual(scoped.extraItems, [URLQueryItem(name: "tag_id", value: "100350")])
    }

    func test_unscopedQuerySendsNeitherTheExtraTagNorTheMatchMode() {
        let unscoped = GammaEventQuery.sportsGamesParams(live: false, startingAfter: nil, cursor: nil)

        XCTAssertNil(unscoped.query["tag_match"], "match mode is meaningless with one tag")
        XCTAssertTrue(unscoped.extraItems.isEmpty)
    }

    func test_excludesClosedGames() {
        XCTAssertEqual(params()["closed"], "false")
    }

    func test_cursorPagesTheSameWayTheRestOfTheFeedDoes() {
        XCTAssertNil(params(cursor: nil)["after_cursor"])
        XCTAssertNil(params(cursor: "")["after_cursor"], "an empty cursor is not a cursor")
        XCTAssertEqual(params(cursor: "abc")["after_cursor"], "abc")
        XCTAssertNil(params()["offset"], "keyset endpoints reject offset with HTTP 422")
    }
}

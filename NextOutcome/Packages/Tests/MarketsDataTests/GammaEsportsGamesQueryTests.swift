//
//  GammaEsportsGamesQueryTests.swift
//  NextOutcome
//
//  Created by Sok Pich on 17/08/2026.
//

import XCTest
import Foundation
@testable import MarketsData
import MarketsDomain

/// The Esports hub's match query — the mirror of the Sports one, scoped *to* esports rather
/// than excluding it.
///
/// These params replaced a bulk read of the whole esports tag: five sequential pages of 100
/// events, measured at 12.6 s and 33 MB against the live API before the hub could render a
/// card, 90 of whose 500 events were season futures discarded on arrival. Both the games
/// filter and the page size move server-side here.
final class GammaEsportsGamesQueryTests: XCTestCase {
    private func params(
        live: Bool = false, startingAfter: Date? = nil, cursor: String? = nil, leagueTagID: String? = nil
    ) -> [String: String] {
        GammaEventQuery.esportsGamesParams(
            live: live, startingAfter: startingAfter, cursor: cursor, leagueTagID: leagueTagID
        ).query
    }

    private func extraItems(leagueTagID: String? = nil) -> [URLQueryItem] {
        GammaEventQuery.esportsGamesParams(
            live: false, startingAfter: nil, cursor: nil, leagueTagID: leagueTagID
        ).extraItems
    }

    func test_intersectsTheEsportsTagWithTheGamesTag() {
        // Gamma ANDs tags by repeating `tag_id` — a comma list is rejected as an invalid
        // integer — so the second tag has to travel as its own query item.
        XCTAssertEqual(params()["tag_id"], "64")
        XCTAssertEqual(params()["tag_match"], "all")
        XCTAssertEqual(extraItems(), [URLQueryItem(name: "tag_id", value: "100639")])
    }

    func test_asksForOnePageRatherThanTheWholeTag() {
        XCTAssertEqual(params()["limit"], "20")
        XCTAssertNil(params()["offset"], "keyset endpoints reject offset with HTTP 422")
    }

    func test_liveQueryAsksForInPlayMatchesOnly() {
        XCTAssertEqual(params(live: true)["live"], "true")
    }

    func test_upcomingQueryOmitsTheLiveFlagEntirely() {
        // `live=false` would exclude in-play matches rather than simply not filtering on them.
        XCTAssertNil(params(live: false)["live"])
    }

    func test_startingAfterIsSentAsAnRFC3339StartTimeBound() {
        let date = Date(timeIntervalSince1970: 1_786_968_000)

        XCTAssertEqual(params(startingAfter: date)["start_time_min"], "2026-08-17T12:00:00Z")
        XCTAssertEqual(params(startingAfter: date)["order"], "startTime")
        XCTAssertEqual(params(startingAfter: date)["ascending"], "true")
    }

    func test_closedMatchesAreExcluded() {
        XCTAssertEqual(params()["closed"], "false")
    }

    func test_cursorPagesTheFeedAndIsOmittedWhenEmpty() {
        XCTAssertEqual(params(cursor: "abc")["after_cursor"], "abc")
        XCTAssertNil(params(cursor: "")["after_cursor"])
        XCTAssertNil(params(cursor: nil)["after_cursor"])
    }

    func test_leagueScopeIsAndedOnAsAThirdRepeatedTag() {
        // The tile row's filter: esports AND games AND this game title.
        XCTAssertEqual(
            extraItems(leagueTagID: "100780"),
            [URLQueryItem(name: "tag_id", value: "100639"),
             URLQueryItem(name: "tag_id", value: "100780")]
        )
    }
}

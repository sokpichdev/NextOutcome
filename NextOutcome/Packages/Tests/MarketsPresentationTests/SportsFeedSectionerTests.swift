//
//  SportsFeedSectionerTests.swift
//  NextOutcome
//
//  Created by Sok Pich on 16/08/2026.
//

import XCTest
import Foundation
@testable import MarketsPresentation
import MarketsDomain

@MainActor
final class SportsFeedSectionerTests: XCTestCase {
    /// Fixed "now" so Today/Tomorrow titles are deterministic: noon, Mon 17 Aug 2026 UTC.
    private let now = Date(timeIntervalSince1970: 1_786_968_000)
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func tag(_ id: String) -> Tag { Tag(id: id, label: id, slug: id) }

    /// A moneyline market, the signal that makes an event a game rather than a future.
    private func moneyline() -> Market {
        Market(id: "ml", question: "Winner", slug: "ml", outcomes: [], volume: 0, liquidity: 0,
               endDate: nil, isResolved: false, imageURL: nil, sportsMarketType: "moneyline")
    }

    /// A schedulable game: kickoff plus a moneyline.
    private func game(
        _ id: String, hoursFromNow: Double, tags: [String] = ["1"], live: Bool = false, ended: Bool = false
    ) -> Event {
        Event(id: id, title: id, slug: id, markets: [moneyline()], volume: 0, imageURL: nil,
              tags: tags.map(tag), gameStartTime: now.addingTimeInterval(hoursFromNow * 3600),
              ended: ended, live: live)
    }

    /// A futures market: no moneyline, so not a game however it is tagged.
    private func future(_ id: String, tags: [String] = ["1"]) -> Event {
        Event(id: id, title: id, slug: id, markets: [], volume: 0, imageURL: nil,
              tags: tags.map(tag), gameStartTime: nil)
    }

    private func sections(_ events: [Event], results: [String: GameResult] = [:]) -> [SportsFeedSection] {
        SportsFeedSectioner.sections(for: events, results: results, now: now, calendar: calendar)
    }

    func test_futuresAreExcludedEntirely() {
        // "UEFA Champions League: 2027 Champion" and the "- More Markets" duplicates have no
        // moneyline; the Futures tab owns them, so the Live feed must not show them at all.
        let result = sections([game("g", hoursFromNow: 2), future("winner-2027")])

        XCTAssertEqual(result.flatMap(\.events).map(\.id), ["g"])
    }

    func test_esportsGamesAreExcluded() {
        // Tag 64 has its own hub, and the chip row above this feed already filters it — leaving
        // esports in the feed would contradict the chips directly above it.
        let result = sections([
            game("soccer", hoursFromNow: 2),
            game("lol", hoursFromNow: 1, tags: ["1", "64"]),
        ])

        XCTAssertEqual(result.flatMap(\.events).map(\.id), ["soccer"])
    }

    func test_inPlayGamesLeadInTheirOwnSection() {
        let result = sections([game("later", hoursFromNow: 5), game("playing", hoursFromNow: -1, live: true)])

        XCTAssertEqual(result.first?.title, "Live now")
        XCTAssertEqual(result.first?.events.map(\.id), ["playing"])
    }

    func test_liveStateFromLoadedResultAlsoCounts() {
        // The feed learns "in play" from /events/results too, not only the event's own flag.
        let event = game("g", hoursFromNow: -1)
        let live = GameResult(eventID: "g", score: "1-0", elapsed: "34", period: "1H",
                              live: true, ended: false, teams: [])

        let result = sections([event], results: ["g": live])

        XCTAssertEqual(result.first?.title, "Live now")
    }

    func test_endedGameStaysInItsDayRatherThanLiveNow() {
        let result = sections([game("final", hoursFromNow: -3, ended: true)])

        XCTAssertEqual(result.map(\.title), ["Today"])
    }

    func test_remainingGamesAreTitledTodayTomorrowThenDated() {
        let result = sections([
            game("d2", hoursFromNow: 48),
            game("today", hoursFromNow: 3),
            game("tomorrow", hoursFromNow: 26),
        ])

        XCTAssertEqual(result.map(\.title), ["Today", "Tomorrow", "Wed 19 Aug"])
        XCTAssertEqual(result.map { $0.events.map(\.id) }, [["today"], ["tomorrow"], ["d2"]])
    }

    func test_gamesWithinADayAreOrderedByKickoff() {
        let result = sections([game("late", hoursFromNow: 8), game("early", hoursFromNow: 2)])

        XCTAssertEqual(result.first?.events.map(\.id), ["early", "late"])
    }

    func test_noGamesYieldsNoSections() {
        XCTAssertTrue(sections([future("a"), future("b")]).isEmpty)
    }
}

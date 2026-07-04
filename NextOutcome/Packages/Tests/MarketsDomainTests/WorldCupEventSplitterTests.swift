//
//  WorldCupEventSplitterTests.swift
//  NextOutcome
//

import XCTest
@testable import MarketsDomain

final class WorldCupEventSplitterTests: XCTestCase {
    private func game(_ id: String, kickoff: Date) -> Event {
        Event(
            id: id, title: "A vs. B", slug: id,
            markets: [.fixture(id: "\(id)-ml", sportsMarketType: "moneyline"),
                      .fixture(id: "\(id)-sp", sportsMarketType: "spreads")],
            volume: 0, imageURL: nil, gameStartTime: kickoff
        )
    }

    private func prop(_ id: String, kickoff: Date? = nil, marketType: String? = nil) -> Event {
        Event(
            id: id, title: "Prop \(id)", slug: id,
            markets: [.fixture(id: "\(id)-m", sportsMarketType: marketType)],
            volume: 0, imageURL: nil, gameStartTime: kickoff
        )
    }

    private let noon = Date(timeIntervalSince1970: 1_782_216_000) // 2026-06-23 12:00 UTC

    func test_split_gameNeedsKickoffAndMoneyline() {
        let events = [
            game("g1", kickoff: noon),
            prop("p1"),                                              // no kickoff, no moneyline
            prop("p2", kickoff: noon, marketType: "soccer_player_goals"), // kickoff but no moneyline
        ]
        let split = WorldCupEventSplitter.split(events)
        XCTAssertEqual(split.games.map(\.id), ["g1"])
        XCTAssertEqual(split.props.map(\.id), ["p1", "p2"])
    }

    func test_gamesByDay_groupsAndSortsAscending() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayTwoLate = game("late", kickoff: noon.addingTimeInterval(86_400 + 3_600))
        let dayTwoEarly = game("early", kickoff: noon.addingTimeInterval(86_400))
        let dayOne = game("first", kickoff: noon)

        let grouped = WorldCupEventSplitter.gamesByDay([dayTwoLate, dayOne, dayTwoEarly], calendar: calendar)

        XCTAssertEqual(grouped.count, 2)
        XCTAssertEqual(grouped[0].games.map(\.id), ["first"])
        XCTAssertEqual(grouped[1].games.map(\.id), ["early", "late"])
        XCTAssertLessThan(grouped[0].day, grouped[1].day)
    }

    func test_moneyline_findsMarketCaseInsensitively() {
        let event = Event(
            id: "e", title: "A vs. B", slug: "e",
            markets: [.fixture(id: "sp", sportsMarketType: "spreads"),
                      .fixture(id: "ml", sportsMarketType: "Moneyline")],
            volume: 0, imageURL: nil
        )
        XCTAssertEqual(WorldCupEventSplitter.moneyline(for: event)?.id, "ml")
        XCTAssertNil(WorldCupEventSplitter.moneyline(for: prop("p")))
    }

    func test_moneylineMarkets_returnsWholeSiblingGroup() {
        // Soccer moneylines are three binary markets: home / draw / away.
        let event = Event(
            id: "e", title: "A vs. B", slug: "e",
            markets: [.fixture(id: "home", sportsMarketType: "moneyline"),
                      .fixture(id: "draw", sportsMarketType: "moneyline"),
                      .fixture(id: "away", sportsMarketType: "moneyline"),
                      .fixture(id: "sp", sportsMarketType: "spreads")],
            volume: 0, imageURL: nil
        )
        XCTAssertEqual(WorldCupEventSplitter.moneylineMarkets(for: event).map(\.id), ["home", "draw", "away"])
    }
}

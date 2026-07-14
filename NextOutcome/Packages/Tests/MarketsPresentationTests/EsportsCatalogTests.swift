import XCTest
@testable import MarketsPresentation
import MarketsDomain

final class EsportsCatalogTests: XCTestCase {
    private func market(sportsMarketType: String? = nil) -> Market {
        Market(
            id: "m1", question: "Q", slug: "m1",
            outcomes: [Outcome(id: "o1", title: "A", price: 0.5), Outcome(id: "o2", title: "B", price: 0.5)],
            volume: 0, liquidity: 0, endDate: nil, isResolved: false,
            imageURL: nil, sportsMarketType: sportsMarketType
        )
    }

    private func event(title: String, tags: [String] = [], markets: [Market] = []) -> Event {
        Event(
            id: "e1", title: title, slug: "e1", markets: markets, volume: 0, imageURL: nil,
            tags: tags.map { Tag(id: $0, label: $0, slug: $0) }
        )
    }

    // MARK: isMatch

    func test_isMatch_moneylineMarket() {
        let e = event(title: "Counter-Strike: QUAZAR vs Brute (BO3) - Playoffs",
                      markets: [market(sportsMarketType: "child_moneyline")])
        XCTAssertTrue(EsportsCatalog.isMatch(e))
    }

    func test_isMatch_gamesTag() {
        let e = event(title: "Some Match", tags: ["esports", "games"])
        XCTAssertTrue(EsportsCatalog.isMatch(e))
    }

    func test_isMatch_vsTitleFallback() {
        let e = event(title: "LoL: G2 NORD vs Team Orange Gaming (BO1) - Prime League")
        XCTAssertTrue(EsportsCatalog.isMatch(e))
    }

    func test_isMatch_futuresEventIsNotMatch() {
        let e = event(title: "LCK 2026 Season Winner", tags: ["esports", "league-of-legends"])
        XCTAssertFalse(EsportsCatalog.isMatch(e))
    }

    // MARK: game(for:)

    func test_game_resolvesFromTagSlug() {
        XCTAssertEqual(EsportsCatalog.game(for: event(title: "t", tags: ["esports", "counter-strike-2"])), .cs2)
        XCTAssertEqual(EsportsCatalog.game(for: event(title: "t", tags: ["league-of-legends"])), .lol)
        XCTAssertEqual(EsportsCatalog.game(for: event(title: "t", tags: ["dota-2"])), .dota2)
        XCTAssertNil(EsportsCatalog.game(for: event(title: "t", tags: ["esports", "rocket-league"])))
    }

    // MARK: matchTitle

    func test_matchTitle_fullShape() {
        let parsed = EsportsCatalog.matchTitle(
            from: "Counter-Strike: QUAZAR vs Brute (BO3) - ESL Challenger League Europe Cup #1 Playoffs"
        )
        XCTAssertEqual(parsed?.homeTeam, "QUAZAR")
        XCTAssertEqual(parsed?.awayTeam, "Brute")
        XCTAssertEqual(parsed?.seriesFormat, "BO3")
        XCTAssertEqual(parsed?.tournament, "ESL Challenger League Europe Cup #1 Playoffs")
    }

    func test_matchTitle_noPrefixNoSeries() {
        let parsed = EsportsCatalog.matchTitle(from: "LUA Gaming vs FALKE Esports")
        XCTAssertEqual(parsed?.homeTeam, "LUA Gaming")
        XCTAssertEqual(parsed?.awayTeam, "FALKE Esports")
        XCTAssertNil(parsed?.seriesFormat)
        XCTAssertNil(parsed?.tournament)
    }

    func test_matchTitle_nonMatchReturnsNil() {
        XCTAssertNil(EsportsCatalog.matchTitle(from: "LCK 2026 Season Winner"))
    }

    // MARK: twitchChannel

    func test_twitchChannel_parsesChannelName() {
        XCTAssertEqual(EsportsCatalog.twitchChannel(from: "https://www.twitch.tv/floppyacs"), "floppyacs")
    }

    func test_twitchChannel_rejectsNonTwitch() {
        XCTAssertNil(EsportsCatalog.twitchChannel(from: "https://lolesports.com/live"))
        XCTAssertNil(EsportsCatalog.twitchChannel(from: ""))
        XCTAssertNil(EsportsCatalog.twitchChannel(from: nil))
    }
}

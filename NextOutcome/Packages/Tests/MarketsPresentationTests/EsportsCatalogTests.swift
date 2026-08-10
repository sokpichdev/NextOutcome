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

    // MARK: league(for:in:)

    /// The live catalogue's primary tag ids, trimmed to what these tests need.
    private var catalogue: [EsportsLeague] {
        [
            EsportsLeague(id: "cs2", name: "CS2", primaryTagID: "100780"),
            EsportsLeague(id: "lol", name: "LoL", primaryTagID: "65"),
            EsportsLeague(id: "val", name: "Valorant", primaryTagID: "101672"),
        ]
    }

    private func tagged(_ pairs: [(id: String, slug: String)]) -> Event {
        Event(
            id: "e1", title: "t", slug: "e1", markets: [], volume: 0, imageURL: nil,
            tags: pairs.map { Tag(id: $0.id, label: $0.slug, slug: $0.slug) }
        )
    }

    func test_league_resolvesFromPrimaryTagID() {
        let e = tagged([("64", "esports"), ("100780", "counter-strike-2")])
        XCTAssertEqual(EsportsCatalog.league(for: e, in: catalogue)?.id, "cs2")
    }

    func test_league_matchesOnIDNotSlug() {
        // The reason this matches ids: CS2 events carry three different slugs for the same
        // game — `cs2` (100677), `counter-strike-2` (100780) and the typo `counter-stike-2`.
        // Only the id the catalogue names as primary is dependable.
        let typo = tagged([("100780", "counter-stike-2")])
        XCTAssertEqual(EsportsCatalog.league(for: typo, in: catalogue)?.id, "cs2")

        // A slug that reads right but carries a non-primary id is not this league.
        let secondary = tagged([("100677", "cs2")])
        XCTAssertNil(EsportsCatalog.league(for: secondary, in: catalogue))
    }

    func test_league_nilForGamesOutsideTheCatalogue() {
        XCTAssertNil(EsportsCatalog.league(for: tagged([("102756", "rocket-league")]), in: catalogue))
        XCTAssertNil(EsportsCatalog.league(for: tagged([]), in: catalogue))
        XCTAssertNil(EsportsCatalog.league(for: tagged([("65", "lol")]), in: []))
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

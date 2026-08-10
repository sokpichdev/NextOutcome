//
//  FetchEsportsLeaguesUseCaseTests.swift
//  NextOutcome
//

import XCTest
import SharedDomain
@testable import MarketsDomain

final class FetchEsportsLeaguesUseCaseTests: XCTestCase {
    func test_execute_scopesToTheEsportsTag() async throws {
        let repo = LeagueSpyRepository(leagues: [])
        _ = try await FetchEsportsLeaguesUseCase(repository: repo).execute()
        let requested = await repo.requestedTagIDs
        XCTAssertEqual(requested, ["64"])
    }

    func test_execute_collapsesDuplicateSeries() async throws {
        // The live catalogue really does ship StarCraft: Brood War twice — slugs `sc` and
        // `sc1`, different tag ids, one shared series id — which would render two tiles for
        // one game.
        let repo = LeagueSpyRepository(leagues: [
            EsportsLeague(id: "cs2", name: "CS2", primaryTagID: "100780", seriesID: "10310"),
            EsportsLeague(id: "sc", name: "StarCraft: Brood War", primaryTagID: "102759", seriesID: "10436"),
            EsportsLeague(id: "sc1", name: "StarCraft: Brood War", primaryTagID: "103065", seriesID: "10436"),
        ])

        let leagues = try await FetchEsportsLeaguesUseCase(repository: repo).execute()

        XCTAssertEqual(leagues.map(\.id), ["cs2", "sc"])   // first occurrence wins
    }

    func test_execute_keepsEntriesWithoutASeries() async throws {
        // Nothing links two series-less rows, so collapsing them would be a guess.
        let repo = LeagueSpyRepository(leagues: [
            EsportsLeague(id: "a", name: "A", primaryTagID: "1"),
            EsportsLeague(id: "b", name: "B", primaryTagID: "2"),
        ])

        let leagues = try await FetchEsportsLeaguesUseCase(repository: repo).execute()

        XCTAssertEqual(leagues.map(\.id), ["a", "b"])
    }

    func test_execute_preservesCatalogueOrder() async throws {
        let repo = LeagueSpyRepository(leagues: [
            EsportsLeague(id: "z", name: "Z", primaryTagID: "1", seriesID: "1"),
            EsportsLeague(id: "a", name: "A", primaryTagID: "2", seriesID: "2"),
        ])

        let leagues = try await FetchEsportsLeaguesUseCase(repository: repo).execute()

        XCTAssertEqual(leagues.map(\.id), ["z", "a"])
    }
}

private actor LeagueSpyRepository: MarketRepository {
    private let leagues: [EsportsLeague]
    private(set) var requestedTagIDs: [String] = []

    init(leagues: [EsportsLeague]) { self.leagues = leagues }

    func fetchLeagues(tagID: String) async throws -> [EsportsLeague] {
        requestedTagIDs.append(tagID)
        return leagues
    }

    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> { Page(items: [], nextCursor: nil) }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
    func fetchEvent(slug: String) async throws -> Event { fatalError("unused") }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func fetchRelatedTags(slug: String) async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
}

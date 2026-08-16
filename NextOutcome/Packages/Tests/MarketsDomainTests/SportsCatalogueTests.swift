//
//  SportsCatalogueTests.swift
//  NextOutcome
//
//  Created by Sok Pich on 16/08/2026.
//

import XCTest
import SharedDomain
@testable import MarketsDomain

final class SportsCatalogueTests: XCTestCase {

    // MARK: SportGroupCatalog.groupTagID

    func test_groupTagID_matchesByMembership_notByPosition() {
        // Most rows read "1,100639,<group>,<league>", but LaLiga is "1,780,100639,100350"
        // with its group tag last. Reading by index would file LaLiga under `100639`.
        let laliga = SportGroupCatalog.groupTagID(
            forTagIDs: ["1", "780", "100639", "100350"], slug: "lal"
        )
        XCTAssertEqual(laliga, "100350", "LaLiga belongs to Soccer regardless of tag order")
    }

    func test_groupTagID_nilWhenLeagueCarriesNoGroupTag() {
        // MLB carries its own tag (100381), never baseball (678). That absence is meaningful:
        // it is what promotes MLB to a top-level row above a separate Baseball group, which
        // is exactly how the reference renders it.
        XCTAssertNil(SportGroupCatalog.groupTagID(forTagIDs: ["1", "100639", "100381"], slug: "mlb"))
        XCTAssertNil(SportGroupCatalog.groupTagID(forTagIDs: ["1", "100639", "279"], slug: "ufc"))
    }

    func test_groupTagID_usesOverrideWhenTagsOmitTheGroup() {
        // NFL is "1,450,100639" — no american-football tag (1186) at all, so only the
        // override table can place it under Football.
        XCTAssertEqual(SportGroupCatalog.groupTagID(forTagIDs: ["1", "450", "100639"], slug: "nfl"), "1186")
    }

    func test_groupTagID_ignoresExtraNonGroupTags() {
        // Setka Cup MD carries two non-primary extras: "103767,105715". Only table tennis
        // (103767) is a group; 105715 is the Setka sub-tag and must not win.
        let setka = SportGroupCatalog.groupTagID(
            forTagIDs: ["1", "100639", "103767", "105715", "105717"], slug: "setkamemd"
        )
        XCTAssertEqual(setka, "103767")
    }

    // MARK: SportGroup aggregates

    private func league(
        _ id: String, group: String?, count: Int, live: Bool = false, volume: Decimal = 0
    ) -> SportLeague {
        SportLeague(
            id: id, name: id.uppercased(), primaryTagID: "tag-\(id)", groupTagID: group,
            activeEventCount: count, hasLive: live, volume: volume
        )
    }

    func test_group_sumsCountsAndVolume_andIsLiveIfAnyLeagueIs() {
        let soccer = SportGroup(id: "100350", name: "Soccer", glyph: "soccerball", leagues: [
            league("epl", group: "100350", count: 140, volume: 297_170),
            league("mls", group: "100350", count: 297, live: true, volume: 1_806_593),
        ])

        XCTAssertEqual(soccer.activeEventCount, 437)
        XCTAssertEqual(soccer.volume, 2_103_763)
        XCTAssertTrue(soccer.hasLive)
        XCTAssertFalse(soccer.isLeaf, "two leagues means a disclosure chevron")
    }

    func test_group_withOneLeagueIsALeaf() {
        let mlb = SportGroup(id: "mlb", name: "MLB", glyph: "baseball.fill", leagues: [
            league("mlb", group: nil, count: 118, live: true),
        ])

        XCTAssertTrue(mlb.isLeaf, "a single-league group renders flat with a count, no chevron")
        XCTAssertEqual(mlb.activeEventCount, 118)
        XCTAssertTrue(mlb.hasLive)
    }

    func test_group_withNoLeaguesIsInert() {
        let empty = SportGroup(id: "x", name: "X", glyph: "sportscourt.fill", leagues: [])

        XCTAssertEqual(empty.activeEventCount, 0)
        XCTAssertFalse(empty.hasLive)
        XCTAssertFalse(empty.isLeaf)
    }
}

@MainActor
final class FetchSportsCatalogueUseCaseTests: XCTestCase {
    private func league(
        _ id: String, group: String?, count: Int, live: Bool = false, volume: Decimal = 0
    ) -> SportLeague {
        SportLeague(
            id: id, name: id.uppercased(), primaryTagID: "tag-\(id)", groupTagID: group,
            activeEventCount: count, hasLive: live, volume: volume
        )
    }

    private func useCase(_ leagues: [SportLeague]) -> FetchSportsCatalogueUseCase {
        FetchSportsCatalogueUseCase(repository: CatalogueFakeRepository(leagues: leagues))
    }

    func test_execute_bucketsLeaguesIntoNamedGroups() async throws {
        let groups = try await useCase([
            league("epl", group: "100350", count: 140, volume: 297_170),
            league("mls", group: "100350", count: 297, volume: 1_806_593),
        ]).execute()

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].id, "100350")
        XCTAssertEqual(groups[0].name, "Soccer")
        XCTAssertEqual(groups[0].glyph, "soccerball")
        XCTAssertEqual(groups[0].activeEventCount, 437)
    }

    func test_execute_ungroupedLeagueBecomesItsOwnLeaf() async throws {
        // The mechanism behind the reference sheet's flat "MLB 130" row sitting above a
        // separate Baseball group.
        let groups = try await useCase([
            league("mlb", group: nil, count: 118, live: true, volume: 5_957_601),
        ]).execute()

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].id, "mlb")
        XCTAssertEqual(groups[0].name, "MLB", "a leaf is named after its league, not a tag")
        XCTAssertTrue(groups[0].isLeaf)
    }

    func test_execute_sortsGroupsByVolumeDescending() async throws {
        let groups = try await useCase([
            league("cyc", group: "102142", count: 3, volume: 4_089),
            league("mlb", group: nil, count: 118, volume: 5_957_601),
            league("epl", group: "100350", count: 140, volume: 297_170),
        ]).execute()

        XCTAssertEqual(groups.map(\.id), ["mlb", "100350", "102142"])
    }

    func test_execute_sortsLeaguesWithinAGroupByVolumeDescending() async throws {
        let groups = try await useCase([
            league("epl", group: "100350", count: 140, volume: 297_170),
            league("mls", group: "100350", count: 297, volume: 1_806_593),
        ]).execute()

        XCTAssertEqual(groups[0].leagues.map(\.id), ["mls", "epl"])
    }

    func test_execute_excludesEsports() async throws {
        // Esports has its own hub; surfacing it here would duplicate that hub's content.
        let groups = try await useCase([
            league("cs2", group: "64", count: 20, volume: 900),
            league("epl", group: "100350", count: 140, volume: 297_170),
        ]).execute()

        XCTAssertEqual(groups.map(\.id), ["100350"])
    }

    func test_execute_unknownGroupTagStillRenders() async throws {
        // Taxonomy drift must degrade, not disappear: a group tag the table doesn't know
        // keeps its leagues visible under the tag id itself.
        let groups = try await useCase([
            league("newsport", group: "999999", count: 5, volume: 10),
            league("newsport2", group: "999999", count: 5, volume: 10),
        ]).execute()

        XCTAssertEqual(groups.map(\.id), ["999999"])
        XCTAssertEqual(groups[0].glyph, SportGroupCatalog.fallbackGlyph)
        XCTAssertEqual(groups[0].activeEventCount, 10)
    }
}

/// A fake repository serving a fixed league catalogue.
private final class CatalogueFakeRepository: MarketRepository, @unchecked Sendable {
    private let leagues: [SportLeague]

    init(leagues: [SportLeague]) { self.leagues = leagues }

    func fetchSportsCatalogue() async throws -> [SportLeague] { leagues }

    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> {
        Page(items: [], nextCursor: nil)
    }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchEvent(slug: String) async throws -> Event { fatalError("unused") }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
}

//
//  FetchRelatedTagsUseCaseTests.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/08/2026.
//

import XCTest
import SharedDomain
@testable import MarketsDomain

final class FetchRelatedTagsUseCaseTests: XCTestCase {
    func test_execute_preservesServerRankOrder() async throws {
        // Response order *is* rank order — no client-side sorting, ever.
        let repo = StubRelatedTagsRepository(row: [
            Tag(id: "1", label: "Trump", slug: "trump", activeEventsCount: 272),
            Tag(id: "2", label: "Fed", slug: "fed", activeEventsCount: 22),
            Tag(id: "3", label: "Gaza", slug: "gaza", activeEventsCount: 15),
        ])

        let tags = try await FetchRelatedTagsUseCase(repository: repo).execute(slug: "all")

        XCTAssertEqual(tags.map(\.label), ["Trump", "Fed", "Gaza"])
    }

    func test_execute_dropsTagsWithNoLiveEvents() async throws {
        // Gamma's `status` parameter is a no-op: dead tags come back in every variant of the
        // request, so the client is the only thing standing between them and the chip row.
        let repo = StubRelatedTagsRepository(row: [
            Tag(id: "1", label: "1H", slug: "1h", activeEventsCount: 356),
            Tag(id: "2", label: "June 27", slug: "may30", activeEventsCount: 0),
            Tag(id: "3", label: "July 1", slug: "weekly-tuesday", activeEventsCount: 0),
            Tag(id: "4", label: "Hit Price", slug: "hit-price", activeEventsCount: 93),
        ])

        let tags = try await FetchRelatedTagsUseCase(repository: repo).execute(slug: "crypto")

        XCTAssertEqual(tags.map(\.label), ["1H", "Hit Price"])
    }

    func test_execute_dropsTagsWithUnknownCount() async throws {
        // `nil` means the endpoint didn't report a count; treat that as "not safe to show"
        // rather than guessing, since only the related-tags shape returns it.
        let repo = StubRelatedTagsRepository(row: [
            Tag(id: "1", label: "Known", slug: "known", activeEventsCount: 4),
            Tag(id: "2", label: "Unknown", slug: "unknown"),
        ])

        let tags = try await FetchRelatedTagsUseCase(repository: repo).execute(slug: "all")

        XCTAssertEqual(tags.map(\.label), ["Known"])
    }

    func test_execute_emptyRowIsNotAnError() async throws {
        // Elections and Mentions genuinely have no sub-topics.
        let repo = StubRelatedTagsRepository(row: [])

        let tags = try await FetchRelatedTagsUseCase(repository: repo).execute(slug: "elections")

        XCTAssertTrue(tags.isEmpty)
    }

    func test_execute_passesSlugThrough() async throws {
        let repo = StubRelatedTagsRepository(row: [])

        _ = try await FetchRelatedTagsUseCase(repository: repo).execute(slug: "top-navbar")

        XCTAssertEqual(repo.requestedSlug, "top-navbar")
    }

    func test_defaultConformance_returnsEmptyRow() async throws {
        // Conformers that don't implement the method fall back to the protocol default.
        let tags = try await FetchRelatedTagsUseCase(repository: DefaultOnlyRepository()).execute(slug: "all")
        XCTAssertTrue(tags.isEmpty)
    }
}

private final class StubRelatedTagsRepository: MarketRepository, @unchecked Sendable {
    let row: [Tag]
    private(set) var requestedSlug: String?

    init(row: [Tag]) { self.row = row }

    func fetchRelatedTags(slug: String) async throws -> [Tag] {
        requestedSlug = slug
        return row
    }

    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> { Page(items: [], nextCursor: nil) }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
    func fetchEvent(slug: String) async throws -> Event { fatalError("unused") }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
}

/// Implements only what the protocol requires, to prove the extension default applies.
private struct DefaultOnlyRepository: MarketRepository {
    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> { Page(items: [], nextCursor: nil) }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
    func fetchEvent(slug: String) async throws -> Event { fatalError("unused") }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
}

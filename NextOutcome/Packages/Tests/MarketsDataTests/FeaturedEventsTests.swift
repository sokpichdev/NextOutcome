import XCTest
@testable import MarketsData
@testable import MarketsDomain
import SharedDomain

/// Polymarket's curated featured list — the editorial ranking the web pins above its
/// volume-sorted feed. See `docs/polymarket-data-freshness.md` §4.
final class FeaturedEventsQueryTests: XCTestCase {
    /// `featured_order=true` is what switches Gamma into the curated ranking; without it
    /// `order=featuredOrder` is meaningless.
    func test_featuredParams_requestCuratedRankingLowestFirst() {
        let params = GammaEventQuery.featuredParams(limit: 12)
        XCTAssertEqual(params["order"], "featuredOrder")
        XCTAssertEqual(params["featured_order"], "true")
        // Ascending, so featuredOrder 1 (the editor's top pick) comes back first.
        XCTAssertEqual(params["ascending"], "true")
        XCTAssertEqual(params["limit"], "12")
    }

    /// A curated pin must never surface a resolved or archived market.
    func test_featuredParams_excludeClosedAndArchived() {
        let params = GammaEventQuery.featuredParams(limit: 5)
        XCTAssertEqual(params["closed"], "false")
        XCTAssertEqual(params["archived"], "false")
        XCTAssertEqual(params["active"], "true")
    }

    /// Keyset endpoints reject `offset` outright (HTTP 422), so it must never be sent.
    func test_featuredParams_neverSendOffset() {
        XCTAssertNil(GammaEventQuery.featuredParams(limit: 5)["offset"])
    }
}

/// The keyset envelope. Unlike bare `/events`, keyset endpoints wrap rows in an object and
/// return an opaque cursor.
final class EventKeysetPageDecodingTests: XCTestCase {
    func test_decodesEventsAndCursor() throws {
        let json = """
        {"events":[{"id":"1","title":"A","slug":"a","volume":"0","markets":[]}],
         "next_cursor":"N-BHqeH5Tvkij6p"}
        """.data(using: .utf8)!
        let page = try JSONDecoder().decode(EventKeysetPageDTO.self, from: json)
        XCTAssertEqual(page.events.count, 1)
        XCTAssertEqual(page.nextCursor, "N-BHqeH5Tvkij6p")
    }

    /// The last page omits the cursor — that's the end-of-list signal, not an error.
    func test_absentCursor_meansLastPage() throws {
        let json = """
        {"events":[{"id":"1","title":"A","slug":"a","volume":"0","markets":[]}]}
        """.data(using: .utf8)!
        let page = try JSONDecoder().decode(EventKeysetPageDTO.self, from: json)
        XCTAssertNil(page.nextCursor)
    }

    /// A malformed/empty envelope degrades to an empty page rather than failing the request.
    func test_missingEventsArray_degradesToEmptyPage() throws {
        let json = "{}".data(using: .utf8)!
        let page = try JSONDecoder().decode(EventKeysetPageDTO.self, from: json)
        XCTAssertTrue(page.events.isEmpty)
        XCTAssertNil(page.nextCursor)
    }
}

/// The 5-minute TTL cache in front of the curated list.
final class FeaturedEventsCacheTests: XCTestCase {
    private func event(_ id: String) -> Event {
        Event(id: id, title: id, slug: id, markets: [], volume: 0, imageURL: nil)
    }

    func test_storedValue_isReturnedWithinTTL() async {
        var now = Date(timeIntervalSince1970: 1_000)
        let cache = FeaturedEventsCache(ttl: 300, now: { now })
        await cache.store([event("a")])
        now = now.addingTimeInterval(299)
        let value = await cache.value()
        XCTAssertEqual(value?.map(\.id), ["a"])
    }

    func test_expiredValue_isEvicted() async {
        var now = Date(timeIntervalSince1970: 1_000)
        let cache = FeaturedEventsCache(ttl: 300, now: { now })
        await cache.store([event("a")])
        now = now.addingTimeInterval(301)
        let value = await cache.value()
        XCTAssertNil(value)
    }

    /// An empty featured list is a real answer worth caching, not a miss to retry.
    func test_emptyList_isACachedValueNotAMiss() async {
        let cache = FeaturedEventsCache(ttl: 300, now: { Date(timeIntervalSince1970: 1_000) })
        await cache.store([])
        let value = await cache.value()
        XCTAssertEqual(value?.count, 0)
        XCTAssertNotNil(value)
    }
}

/// The use case drops finished fixtures — pinning a match that has already been played is
/// the exact failure this work exists to fix.
final class FetchFeaturedEventsUseCaseTests: XCTestCase {
    private struct FeaturedRepo: MarketRepository {
        let events: [Event]
        func fetchFeaturedEvents(limit: Int) async throws -> [Event] { events }
        // Unused by these tests.
        func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> { Page(items: [], nextCursor: nil) }
        func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
        func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
        func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
        func fetchEvent(slug: String) async throws -> Event { throw CancellationError() }
        func searchMarkets(query: String) async throws -> [Market] { [] }
        func fetchTags() async throws -> [Tag] { [] }
        func holders(conditionId: String) async throws -> [Holder] { [] }
        func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
        func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
    }

    private func event(_ id: String, ended: Bool?) -> Event {
        Event(id: id, title: id, slug: id, markets: [], volume: 0, imageURL: nil, ended: ended)
    }

    func test_dropsEndedFixtures_keepsRankOrder() async throws {
        let repo = FeaturedRepo(events: [
            event("fed", ended: nil),        // ordinary market — no flag
            event("finished-match", ended: true),
            event("upcoming-match", ended: false),
        ])
        let events = try await FetchFeaturedEventsUseCase(repository: repo).execute()
        XCTAssertEqual(events.map(\.id), ["fed", "upcoming-match"])
    }
}

import XCTest
@testable import MarketsData
import MarketsDomain
import SharedDomain

/// Gamma leaves a long tail of events whose window closed but which were never marked
/// `closed`, so a `closed=false` query keeps returning them — the Crypto tag's list carries
/// 5-minute windows from December 2025 still reported as open. See
/// `docs/polymarket-crypto-hub-gaps.md` §3.
final class AbandonedEventTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_785_764_400)  // 2026-08-03T13:40:00Z

    private func event(id: String, endDate: Date?, volume24hr: Decimal) -> Event {
        Event(id: id, title: id, slug: id, markets: [], volume: 0, imageURL: nil,
              volume24hr: volume24hr, endDate: endDate)
    }

    /// The real shape of the orphans: window long past, nobody trading.
    func test_pastWindowWithNoTrading_isAbandoned() {
        let december = Date(timeIntervalSince1970: 1_766_162_100)  // 2025-12-19T16:35:00Z
        XCTAssertTrue(event(id: "orphan", endDate: december, volume24hr: 0).isAbandoned(asOf: now))
    }

    /// A market that just closed but is still being traded is *not* abandoned — that's a
    /// fixture awaiting resolution, which the `ENDED` badge already handles.
    func test_pastWindowStillTrading_isNotAbandoned() {
        let anHourAgo = now.addingTimeInterval(-3600)
        XCTAssertFalse(event(id: "recent", endDate: anHourAgo, volume24hr: 5_000).isAbandoned(asOf: now))
    }

    /// A quiet market that hasn't closed yet is perfectly normal — a brand-new 5-minute
    /// window has zero volume by definition and must never be dropped.
    func test_futureWindowWithNoTrading_isNotAbandoned() {
        XCTAssertFalse(event(id: "fresh", endDate: now.addingTimeInterval(300), volume24hr: 0).isAbandoned(asOf: now))
    }

    /// No end date is not evidence of abandonment — dropping these would hide open-ended
    /// markets like "Who will be arrested before 2027?", which genuinely carry no `endDate`.
    func test_missingEndDate_isNeverAbandoned() {
        XCTAssertFalse(event(id: "openended", endDate: nil, volume24hr: 0).isAbandoned(asOf: now))
    }

    /// The boundary instant itself is not yet past.
    func test_endDateExactlyNow_isNotAbandoned() {
        XCTAssertFalse(event(id: "boundary", endDate: now, volume24hr: 0).isAbandoned(asOf: now))
    }
}

/// Where the filter is applied, and — just as importantly — where it isn't.
final class FetchAllEventsFilteringTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_785_764_400)

    private struct Repo: MarketRepository {
        let events: [Event]
        private(set) var requestedStatus: EventStatus?
        func fetchAllEvents(tagID: String, status: EventStatus) async throws -> [Event] { events }
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

    private var mixed: [Event] {
        let december = Date(timeIntervalSince1970: 1_766_162_100)
        return [
            Event(id: "orphan", title: "orphan", slug: "orphan", markets: [], volume: 0, imageURL: nil,
                  volume24hr: 0, endDate: december),
            Event(id: "live", title: "live", slug: "live", markets: [], volume: 0, imageURL: nil,
                  volume24hr: 1_000, endDate: now.addingTimeInterval(300)),
        ]
    }

    func test_activeStatus_dropsAbandonedEvents() async throws {
        let useCase = FetchAllEventsUseCase(repository: Repo(events: mixed), now: { self.now })
        let events = try await useCase.execute(tagID: "21", status: .active)
        XCTAssertEqual(events.map(\.id), ["live"])
    }

    /// `.all` is what the team-profile screen uses to build a match history. Filtering there
    /// would delete every completed game — the exact opposite of what the caller asked for.
    func test_allStatus_keepsPastEvents() async throws {
        let useCase = FetchAllEventsUseCase(repository: Repo(events: mixed), now: { self.now })
        let events = try await useCase.execute(tagID: "1", status: .all)
        XCTAssertEqual(events.map(\.id), ["orphan", "live"])
    }

    /// Same reasoning for an explicit request for resolved events.
    func test_resolvedStatus_keepsPastEvents() async throws {
        let useCase = FetchAllEventsUseCase(repository: Repo(events: mixed), now: { self.now })
        let events = try await useCase.execute(tagID: "1", status: .resolved)
        XCTAssertEqual(events.map(\.id), ["orphan", "live"])
    }
}

/// The tag query's ordering. Every caller re-sorts client-side, but the fetch is capped at
/// 5 pages — so `order` decides which 500 events the hub ever sees.
final class TagParamsOrderingTests: XCTestCase {
    func test_tagParams_orderByVolume24hrDescending() {
        let params = GammaEventQuery.tagParams(tagID: "21", offset: 0, status: .active)
        XCTAssertEqual(params["order"], "volume24hr")
        XCTAssertEqual(params["ascending"], "false")
    }

    /// Ordering must not disturb the existing filter contract: hub fetches deliberately omit
    /// `active` so in-play games survive, and only exclude resolved events.
    func test_tagParams_stillBoundsByClosedOnly() {
        let params = GammaEventQuery.tagParams(tagID: "21", offset: 0, status: .active)
        XCTAssertEqual(params["closed"], "false")
        XCTAssertNil(params["active"])
    }

    func test_tagParams_orderAppliesToEveryPage() {
        XCTAssertEqual(GammaEventQuery.tagParams(tagID: "21", offset: 400, status: .all)["order"], "volume24hr")
    }
}

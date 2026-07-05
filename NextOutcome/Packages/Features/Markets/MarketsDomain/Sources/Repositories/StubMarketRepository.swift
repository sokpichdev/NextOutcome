//
//  StubMarketRepository.swift
//  NextOutcome
//
//  Test-only stub that satisfies MarketRepository with empty responses.
//  Used by FetchEventsUseCase.stub and FetchTagsUseCase.stub.
//

import Foundation
import SharedDomain

/// A do-nothing `MarketRepository` for previews and unit tests: every method returns an
/// empty result (and `fetchEvent` throws), so use-case `.stub` instances can be built
/// without any real networking. DEBUG-only.
#if DEBUG
struct StubMarketRepository: MarketRepository {
    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> {
        Page(items: [], nextCursor: nil)
    }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> {
        Page(items: [], nextCursor: nil)
    }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchEvent(slug: String) async throws -> Event {
        throw URLError(.unknown)
    }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
}
#endif

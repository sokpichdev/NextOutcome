//
//  StubMarketRepository.swift
//  NextOutcome
//
//  Test-only stub that satisfies MarketRepository with empty responses.
//  Used by FetchEventsUseCase.stub and FetchTagsUseCase.stub.
//

import Foundation
import SharedDomain

#if DEBUG
struct StubMarketRepository: MarketRepository {
    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus) async throws -> Page<Event> {
        Page(items: [], nextCursor: nil)
    }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> {
        Page(items: [], nextCursor: nil)
    }
    func fetchEvent(slug: String) async throws -> Event {
        throw URLError(.unknown)
    }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
}
#endif

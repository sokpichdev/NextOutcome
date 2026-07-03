//
//  HideSportsPaginationTests.swift
//  NextOutcome
//

import XCTest
@testable import MarketsPresentation
import MarketsDomain
import SharedDomain

#if DEBUG
/// Stub repository that serves a pre-queued list of pages in order.
private final class QueuedPageRepository: MarketRepository {
    private var pages: [Page<Event>]
    private var index = 0

    init(pages: [Page<Event>]) { self.pages = pages }

    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus) async throws -> Page<Event> {
        guard index < pages.count else { return Page(items: [], nextCursor: nil) }
        defer { index += 1 }
        return pages[index]
    }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
    func fetchEvent(slug: String) async throws -> Event { throw URLError(.unknown) }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
}

private func sportsEvent(id: String) -> Event {
    Event(id: id, title: "Game \(id)", slug: "g\(id)", markets: [], volume: 0, imageURL: nil,
          tags: [Tag(id: "sports", label: "Sports", slug: "sports")])
}

private func politicsEvent(id: String) -> Event {
    Event(id: id, title: "Vote \(id)", slug: "v\(id)", markets: [], volume: 0, imageURL: nil,
          tags: [Tag(id: "politics", label: "Politics", slug: "politics")])
}

@MainActor
final class HideSportsPaginationTests: XCTestCase {
    func test_loadMore_advancesPastAllSportsPage_whenHideSportsEnabled() async throws {
        // page1 = all sports (already loaded), page2 = politics
        let page1Items = [sportsEvent(id: "s1"), sportsEvent(id: "s2")]
        let page2 = Page(items: [politicsEvent(id: "p1")], nextCursor: nil)

        let repo = QueuedPageRepository(pages: [page2])
        let fetchEvents = FetchEventsUseCase(repository: repo)
        let vm = EventListViewModel(fetchEvents: fetchEvents, fetchTags: FetchTagsUseCase.stub)

        // Seed: page1 already loaded, cursor points to page2, hideSports=true
        vm.seedForTesting(
            state: .loaded(page1Items),
            nextCursor: "20",
            hideSports: true
        )

        await vm.loadMore()

        XCTAssertTrue(
            vm.visibleEvents.contains { $0.id == "p1" },
            "politics event should appear in visibleEvents after loadMore skips all-sports page"
        )
    }
}
#endif

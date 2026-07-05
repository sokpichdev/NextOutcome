//
//  TrendingChipSelectionTests.swift
//  NextOutcome
//

import XCTest
import SharedDomain
@testable import MarketsPresentation
import MarketsDomain
import DesignSystem

@MainActor
final class TrendingChipSelectionTests: XCTestCase {
    private func tag(_ label: String) -> Tag { Tag(id: "id-\(label)", label: label, slug: label.lowercased()) }

    private func event(_ id: String, tags: [Tag] = []) -> Event {
        Event(id: id, title: "e\(id)", slug: "e\(id)", markets: [], volume: 0, imageURL: nil, tags: tags)
    }

    private func makeVM(events: [Event], nextCursor: String? = nil) -> (EventListViewModel, RecordingMarketRepository) {
        let repo = RecordingMarketRepository(page: Page(items: events, nextCursor: nextCursor))
        let vm = EventListViewModel(
            fetchEvents: FetchEventsUseCase(repository: repo),
            fetchTags: FetchTagsUseCase(repository: repo),
            searchEvents: SearchEventsUseCase(repository: repo)
        )
        return (vm, repo)
    }

    private var chipEvents: [Event] {
        // Two events sharing "Trump" + "Iran" so both survive minCount 2.
        [event("1", tags: [tag("Trump"), tag("Iran")]),
         event("2", tags: [tag("Trump"), tag("Iran")])]
    }

    func test_initialTrendingLoad_derivesChips_withNoTagFilter() async {
        let (vm, repo) = makeVM(events: chipEvents)
        await vm.apply(category: .trending)

        XCTAssertEqual(repo.fetchedTagIDs, [nil])
        XCTAssertEqual(vm.trendingChips.map(\.label).sorted(), ["Iran", "Trump"])
        XCTAssertTrue(vm.showsTrendingChips)
        XCTAssertNil(vm.selectedTrendingTagID)
    }

    func test_applySameCategoryTwice_fetchesOnce() async {
        let (vm, repo) = makeVM(events: chipEvents)
        await vm.apply(category: .trending)
        await vm.apply(category: .trending)
        XCTAssertEqual(repo.fetchedTagIDs.count, 1)
    }

    func test_selectChip_refetchesWithChipTag_andKeepsChips() async {
        let (vm, repo) = makeVM(events: chipEvents)
        await vm.apply(category: .trending)
        let chips = vm.trendingChips

        // The filtered page has different tags; chips must not be re-derived from it.
        repo.page = Page(items: [event("9", tags: [tag("Other")])], nextCursor: nil)
        await vm.selectTrendingChip(tagID: "id-Trump")

        XCTAssertEqual(repo.fetchedTagIDs, [nil, "id-Trump"])
        XCTAssertEqual(vm.selectedTrendingTagID, "id-Trump")
        XCTAssertEqual(vm.trendingChips, chips)
    }

    func test_selectSameChipTwice_isNoOp() async {
        let (vm, repo) = makeVM(events: chipEvents)
        await vm.apply(category: .trending)
        await vm.selectTrendingChip(tagID: "id-Trump")
        await vm.selectTrendingChip(tagID: "id-Trump")
        XCTAssertEqual(repo.fetchedTagIDs, [nil, "id-Trump"])
    }

    func test_loadMore_carriesChipTag_andResetCursorOnSelect() async {
        let (vm, repo) = makeVM(events: chipEvents, nextCursor: "20")
        await vm.apply(category: .trending)
        await vm.selectTrendingChip(tagID: "id-Trump")

        // Chip selection must reload from the top (cursor nil)…
        XCTAssertEqual(repo.fetchedCursors, [nil, nil])

        // …and pagination under an active chip carries the chip's tag id.
        repo.page = Page(items: [event("3")], nextCursor: nil)
        await vm.loadMore()
        XCTAssertEqual(repo.fetchedTagIDs.last, "id-Trump")
        XCTAssertEqual(repo.fetchedCursors.last, "20")
    }

    func test_categorySwitch_clearsChipSelection_keepsChipsCached() async throws {
        let (vm, repo) = makeVM(events: chipEvents)
        await vm.apply(category: .trending)
        await vm.selectTrendingChip(tagID: "id-Trump")

        await vm.apply(category: .politics)
        XCTAssertNil(vm.selectedTrendingTagID)
        XCTAssertEqual(repo.fetchedTagIDs.last, "2")
        XCTAssertFalse(vm.showsTrendingChips)     // hidden off Trending…
        XCTAssertFalse(vm.trendingChips.isEmpty)  // …but cached for the way back.

        await vm.apply(category: .trending)
        XCTAssertNil(try XCTUnwrap(repo.fetchedTagIDs.last)) // back to the unfiltered feed
        XCTAssertTrue(vm.showsTrendingChips)
    }

    func test_selectChip_ignoredOffTrending() async {
        let (vm, repo) = makeVM(events: chipEvents)
        await vm.apply(category: .politics)
        await vm.selectTrendingChip(tagID: "id-Trump")
        XCTAssertNil(vm.selectedTrendingTagID)
        XCTAssertEqual(repo.fetchedTagIDs, ["2"])
    }
}

private final class RecordingMarketRepository: MarketRepository, @unchecked Sendable {
    var page: Page<Event>
    private(set) var fetchedTagIDs: [String?] = []
    private(set) var fetchedCursors: [String?] = []

    init(page: Page<Event>) { self.page = page }

    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> {
        fetchedTagIDs.append(tagID)
        fetchedCursors.append(cursor)
        return page
    }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchEvent(slug: String) async throws -> Event { fatalError("unused") }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
}

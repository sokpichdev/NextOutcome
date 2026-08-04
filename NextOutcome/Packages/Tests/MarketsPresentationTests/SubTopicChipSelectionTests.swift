//
//  SubTopicChipSelectionTests.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/08/2026.
//

import XCTest
import SharedDomain
@testable import MarketsPresentation
import MarketsDomain
import DesignSystem

@MainActor
final class SubTopicChipSelectionTests: XCTestCase {
    private func tag(_ label: String, count: Int? = 5) -> Tag {
        Tag(id: "id-\(label)", label: label, slug: label.lowercased(), activeEventsCount: count)
    }

    private func event(_ id: String) -> Event {
        Event(id: id, title: "e\(id)", slug: "e\(id)", markets: [], volume: 0, imageURL: nil, tags: [])
    }

    private func makeVM(
        events: [Event] = [],
        nextCursor: String? = nil,
        rows: [String: [Tag]] = [:]
    ) -> (EventListViewModel, RecordingMarketRepository) {
        let repo = RecordingMarketRepository(page: Page(items: events, nextCursor: nextCursor), rows: rows)
        let vm = EventListViewModel(
            fetchEvents: FetchEventsUseCase(repository: repo),
            fetchRelatedTags: FetchRelatedTagsUseCase(repository: repo),
            searchEvents: SearchEventsUseCase(repository: repo),
            fetchFeaturedEvents: FetchFeaturedEventsUseCase(repository: repo)
        )
        return (vm, repo)
    }

    /// The sub-topic rows Gamma returns for the two categories these tests exercise.
    private var rows: [String: [Tag]] {
        ["all": [tag("Trump"), tag("Fed")],
         "politics": [tag("Midterms")]]
    }

    func test_initialLoad_fetchesSubTopicsForCategory_withNoTagFilter() async {
        let (vm, repo) = makeVM(events: [event("1")], rows: rows)
        await vm.apply(category: .all)

        XCTAssertEqual(repo.fetchedTagIDs, [nil])          // "All" sends no tag filter
        XCTAssertEqual(repo.requestedRowSlugs, ["all"])
        XCTAssertEqual(vm.subTopicChips.map(\.label), ["Trump", "Fed"])  // server rank order
        XCTAssertTrue(vm.showsSubTopicChips)
        XCTAssertNil(vm.selectedSubTopicTagID)
    }

    func test_categoryWithNoSubTopics_hidesTheRow() async {
        // Several categories (Elections, Mentions) genuinely return an empty row. That's a
        // normal answer, not an error — the row just doesn't render.
        let (vm, _) = makeVM(events: [event("1")], rows: [:])
        await vm.apply(category: .all)

        XCTAssertTrue(vm.subTopicChips.isEmpty)
        XCTAssertFalse(vm.showsSubTopicChips)
    }

    func test_applySameCategoryTwice_fetchesOnce() async {
        let (vm, repo) = makeVM(events: [event("1")], rows: rows)
        await vm.apply(category: .all)
        await vm.apply(category: .all)
        XCTAssertEqual(repo.fetchedTagIDs.count, 1)
    }

    func test_selectChip_refetchesWithChipTag() async {
        let (vm, repo) = makeVM(events: [event("1")], rows: rows)
        await vm.apply(category: .all)
        let chips = vm.subTopicChips

        await vm.selectSubTopicChip(tagID: "id-Trump")

        XCTAssertEqual(repo.fetchedTagIDs, [nil, "id-Trump"])
        XCTAssertEqual(vm.selectedSubTopicTagID, "id-Trump")
        // The row is category-scoped, so filtering with it must not reshuffle it.
        XCTAssertEqual(vm.subTopicChips, chips)
    }

    func test_selectSameChipTwice_isNoOp() async {
        let (vm, repo) = makeVM(events: [event("1")], rows: rows)
        await vm.apply(category: .all)
        await vm.selectSubTopicChip(tagID: "id-Trump")
        await vm.selectSubTopicChip(tagID: "id-Trump")
        XCTAssertEqual(repo.fetchedTagIDs, [nil, "id-Trump"])
    }

    func test_loadMore_carriesChipTag_andSelectResetsCursor() async {
        let (vm, repo) = makeVM(events: [event("1")], nextCursor: "20", rows: rows)
        await vm.apply(category: .all)
        await vm.selectSubTopicChip(tagID: "id-Trump")

        // Chip selection reloads from the top…
        XCTAssertEqual(repo.fetchedCursors, [nil, nil])

        // …and pagination under an active chip carries the chip's tag id.
        await vm.loadMore()
        XCTAssertEqual(repo.fetchedTagIDs.last, "id-Trump")
        XCTAssertEqual(repo.fetchedCursors.last, "20")
    }

    func test_categorySwitch_swapsTheRow_andClearsSelection() async {
        let (vm, repo) = makeVM(events: [event("1")], rows: rows)
        await vm.apply(category: .all)
        await vm.selectSubTopicChip(tagID: "id-Trump")

        await vm.apply(category: .politics)

        // A sub-topic belongs to the category it came from.
        XCTAssertNil(vm.selectedSubTopicTagID)
        XCTAssertEqual(vm.subTopicChips.map(\.label), ["Midterms"])
        XCTAssertEqual(repo.requestedRowSlugs, ["all", "politics"])
        XCTAssertEqual(repo.fetchedTagIDs.last, "2")   // Politics's own tag id
    }

    func test_deadTagsAreDroppedFromTheRow() async {
        // Gamma keeps expired topics in the payload regardless of `status`.
        let (vm, _) = makeVM(events: [event("1")], rows: [
            "all": [tag("Trump"), tag("June 27", count: 0), tag("Fed", count: nil)]
        ])
        await vm.apply(category: .all)

        XCTAssertEqual(vm.subTopicChips.map(\.label), ["Trump"])
    }

    func test_rowFetchFailure_leavesRowHiddenButStillLoadsFeed() async {
        let (vm, repo) = makeVM(events: [event("1")], rows: [:])
        repo.failingRowSlugs = ["all"]

        await vm.apply(category: .all)

        XCTAssertFalse(vm.showsSubTopicChips)
        XCTAssertEqual(repo.fetchedTagIDs, [nil])   // the feed still loaded
    }
}

private final class RecordingMarketRepository: MarketRepository, @unchecked Sendable {
    var page: Page<Event>
    var rows: [String: [Tag]]
    var failingRowSlugs: Set<String> = []
    private(set) var fetchedTagIDs: [String?] = []
    private(set) var fetchedCursors: [String?] = []
    private(set) var requestedRowSlugs: [String] = []

    init(page: Page<Event>, rows: [String: [Tag]] = [:]) {
        self.page = page
        self.rows = rows
    }

    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> {
        fetchedTagIDs.append(tagID)
        fetchedCursors.append(cursor)
        return page
    }
    func fetchRelatedTags(slug: String) async throws -> [Tag] {
        requestedRowSlugs.append(slug)
        if failingRowSlugs.contains(slug) { throw URLError(.unknown) }
        return rows[slug] ?? []
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

// NextOutcome/Packages/Tests/MarketsPresentationTests/HubTabsViewModelTests.swift
import XCTest
import Foundation
import SharedDomain
@testable import MarketsPresentation
import MarketsDomain
import DesignSystem

@MainActor
final class HubTabsViewModelTests: XCTestCase {
    /// The shape of the live `top-navbar` row, trimmed to what these tests need.
    private func navRow() -> [Tag] {
        [
            Tag(id: "100215", label: "All", slug: "all", activeEventsCount: 2),
            Tag(id: "2", label: "Politics", slug: "politics", activeEventsCount: 1556),
            Tag(id: "21", label: "Crypto", slug: "crypto", activeEventsCount: 3515),
        ]
    }

    func test_init_seedsWithFallbackRail() {
        let vm = HubTabsViewModel(fetchRelatedTags: FetchRelatedTagsUseCase(repository: SpyMarketRepository()))
        XCTAssertEqual(vm.tabs, HubTab.fallbackNav)
    }

    func test_load_replacesRailWithServerRowInRankOrder() async {
        let repo = SpyMarketRepository(rowsBySlug: ["top-navbar": navRow()])
        let vm = HubTabsViewModel(fetchRelatedTags: FetchRelatedTagsUseCase(repository: repo))

        await vm.loadDynamicTabsIfNeeded()

        // Replaced wholesale, not appended to the fallback.
        XCTAssertEqual(vm.tabs.map(\.id), ["all", "politics", "crypto"])
        XCTAssertEqual(vm.tabs.map(\.title), ["All", "Politics", "Crypto"])
    }

    func test_load_mapsAllToNoTagFilter() async {
        // The trap this guards: `all` is a real tag, but querying tag_id=100215 returns the
        // two events literally tagged "all" instead of the full feed.
        let repo = SpyMarketRepository(rowsBySlug: ["top-navbar": navRow()])
        let vm = HubTabsViewModel(fetchRelatedTags: FetchRelatedTagsUseCase(repository: repo))

        await vm.loadDynamicTabsIfNeeded()

        XCTAssertNil(vm.tabs.first(where: { $0.id == "all" })?.tagID)
        XCTAssertEqual(vm.tabs.first(where: { $0.id == "politics" })?.tagID, "2")
        XCTAssertEqual(vm.tabs.first(where: { $0.id == "crypto" })?.tagID, "21")
    }

    func test_load_rendersTextOnlyChips() async {
        let repo = SpyMarketRepository(rowsBySlug: ["top-navbar": navRow()])
        let vm = HubTabsViewModel(fetchRelatedTags: FetchRelatedTagsUseCase(repository: repo))

        await vm.loadDynamicTabsIfNeeded()

        XCTAssertTrue(vm.tabs.allSatisfy { $0.glyph == nil })
    }

    func test_load_dropsDeadTags() async {
        // Gamma's status=active is a no-op, so expired topics arrive with a zero count.
        let repo = SpyMarketRepository(rowsBySlug: ["top-navbar": [
            Tag(id: "100215", label: "All", slug: "all", activeEventsCount: 2),
            Tag(id: "999", label: "June 27", slug: "may30", activeEventsCount: 0),
        ]])
        let vm = HubTabsViewModel(fetchRelatedTags: FetchRelatedTagsUseCase(repository: repo))

        await vm.loadDynamicTabsIfNeeded()

        XCTAssertEqual(vm.tabs.map(\.id), ["all"])
    }

    func test_load_keepsFallbackWhenFetchFails() async {
        let repo = SpyMarketRepository(failingSlugs: ["top-navbar"])
        let vm = HubTabsViewModel(fetchRelatedTags: FetchRelatedTagsUseCase(repository: repo))

        await vm.loadDynamicTabsIfNeeded()

        XCTAssertEqual(vm.tabs, HubTab.fallbackNav)
    }

    func test_load_keepsFallbackWhenRowIsEmpty() async {
        // An empty nav row would blank the rail entirely — never take it.
        let repo = SpyMarketRepository(rowsBySlug: ["top-navbar": []])
        let vm = HubTabsViewModel(fetchRelatedTags: FetchRelatedTagsUseCase(repository: repo))

        await vm.loadDynamicTabsIfNeeded()

        XCTAssertEqual(vm.tabs, HubTab.fallbackNav)
    }

    func test_load_isIdempotent() async {
        let repo = SpyMarketRepository(rowsBySlug: ["top-navbar": navRow()])
        let vm = HubTabsViewModel(fetchRelatedTags: FetchRelatedTagsUseCase(repository: repo))

        await vm.loadDynamicTabsIfNeeded()
        await vm.loadDynamicTabsIfNeeded()

        // One request for the whole rail, replacing the old 11-request slug fan-out.
        let calls = await repo.requestedSlugs
        XCTAssertEqual(calls, ["top-navbar"])
    }
}

private actor SpyMarketRepository: MarketRepository {
    private let rowsBySlug: [String: [Tag]]
    private let failingSlugs: Set<String>
    private(set) var requestedSlugs: [String] = []

    init(rowsBySlug: [String: [Tag]] = [:], failingSlugs: Set<String> = []) {
        self.rowsBySlug = rowsBySlug
        self.failingSlugs = failingSlugs
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

    func fetchRelatedTags(slug: String) async throws -> [Tag] {
        requestedSlugs.append(slug)
        if failingSlugs.contains(slug) { throw URLError(.unknown) }
        return rowsBySlug[slug] ?? []
    }
}

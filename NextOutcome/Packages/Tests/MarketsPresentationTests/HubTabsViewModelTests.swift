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
    ///
    /// `all` really does come back with `activeEventsCount: 0` — it is a pseudo-tag that
    /// nothing is tagged with. Fixtures here once gave it a non-zero count, which hid the fact
    /// that the dead-tag filter was eating the chip in production; keep it at 0.
    private func navRow() -> [Tag] {
        [
            Tag(id: "100215", label: "All", slug: "all", activeEventsCount: 0),
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

        // Replaced wholesale, not appended to the fallback. `esports` is the app-owned entry
        // injected after Crypto — see test_load_injectsEsportsAfterCryptoWhenServerOmitsIt.
        XCTAssertEqual(vm.tabs.map(\.id), ["all", "politics", "crypto", "esports"])
        XCTAssertEqual(vm.tabs.map(\.title), ["All", "Politics", "Crypto", "Esports"])
    }

    func test_load_injectsEsportsAfterCryptoWhenServerOmitsIt() async {
        // Gamma's top-navbar row has no `esports` entry, yet polymarket.com shows one — their
        // web client injects it after Crypto. Without the same step our EsportsHubView has no
        // route: the rail is its only entry point.
        let repo = SpyMarketRepository(rowsBySlug: ["top-navbar": navRow()])
        let vm = HubTabsViewModel(fetchRelatedTags: FetchRelatedTagsUseCase(repository: repo))

        await vm.loadDynamicTabsIfNeeded()

        XCTAssertEqual(vm.tabs.map(\.id), ["all", "politics", "crypto", "esports"])
        // `64` is the esports tag; `100639` is the broader `games` tag and would widen the hub.
        XCTAssertEqual(vm.tabs.first(where: { $0.id == "esports" })?.tagID, "64")
    }

    func test_load_doesNotDuplicateEsportsWhenServerProvidesIt() async {
        // The injection has to retire itself the day Polymarket adds the tag to the nav row,
        // deferring to the server's label, id and rank.
        let repo = SpyMarketRepository(rowsBySlug: ["top-navbar": [
            Tag(id: "100215", label: "All", slug: "all", activeEventsCount: 0),
            Tag(id: "64", label: "Esports & Gaming", slug: "esports", activeEventsCount: 751),
            Tag(id: "21", label: "Crypto", slug: "crypto", activeEventsCount: 3515),
        ]])
        let vm = HubTabsViewModel(fetchRelatedTags: FetchRelatedTagsUseCase(repository: repo))

        await vm.loadDynamicTabsIfNeeded()

        XCTAssertEqual(vm.tabs.filter { $0.id == "esports" }.count, 1)
        // Server rank kept — not moved to sit after Crypto.
        XCTAssertEqual(vm.tabs.map(\.id), ["all", "esports", "crypto"])
        XCTAssertEqual(vm.tabs.first(where: { $0.id == "esports" })?.title, "Esports & Gaming")
    }

    func test_load_appendsEsportsWhenCryptoAbsent() async {
        let repo = SpyMarketRepository(rowsBySlug: ["top-navbar": [
            Tag(id: "100215", label: "All", slug: "all", activeEventsCount: 0),
            Tag(id: "2", label: "Politics", slug: "politics", activeEventsCount: 1556),
        ]])
        let vm = HubTabsViewModel(fetchRelatedTags: FetchRelatedTagsUseCase(repository: repo))

        await vm.loadDynamicTabsIfNeeded()

        XCTAssertEqual(vm.tabs.map(\.id), ["all", "politics", "esports"])
    }

    func test_fallbackNav_containsEsports() {
        // The offline rail is the only rail until the fetch lands; dropping esports there
        // would make the hub unreachable on a cold or offline launch.
        XCTAssertTrue(HubTab.fallbackNav.contains(HubTab.esports))
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
            Tag(id: "2", label: "Politics", slug: "politics", activeEventsCount: 1556),
            Tag(id: "999", label: "June 27", slug: "may30", activeEventsCount: 0),
        ]])
        let vm = HubTabsViewModel(fetchRelatedTags: FetchRelatedTagsUseCase(repository: repo))

        await vm.loadDynamicTabsIfNeeded()

        XCTAssertFalse(vm.tabs.contains { $0.id == "may30" })
        XCTAssertEqual(vm.tabs.map(\.id), ["all", "politics", "esports"])
    }

    func test_load_restoresAllChipDroppedByTheDeadTagFilter() async {
        // The regression this guards: `all` is ranked first by Gamma but reports
        // `activeEventsCount: 0`, so FetchRelatedTagsUseCase's dead-tag filter removes it. The
        // rail then lost its default category the moment the live row landed, with no way back
        // to the unfiltered feed.
        let repo = SpyMarketRepository(rowsBySlug: ["top-navbar": navRow()])
        let vm = HubTabsViewModel(fetchRelatedTags: FetchRelatedTagsUseCase(repository: repo))

        await vm.loadDynamicTabsIfNeeded()

        XCTAssertEqual(vm.tabs.first?.id, "all")
        XCTAssertEqual(vm.tabs.first?.title, "All")
        // Restored as the pseudo-tab, so it still queries no tag at all.
        XCTAssertNil(vm.tabs.first?.tagID)
    }

    func test_load_doesNotDuplicateAllWhenTheServerRowKeepsIt() async {
        // Should Gamma ever give `all` a live count, the fetched entry must win outright.
        let repo = SpyMarketRepository(rowsBySlug: ["top-navbar": [
            Tag(id: "2", label: "Politics", slug: "politics", activeEventsCount: 1556),
            Tag(id: "100215", label: "All", slug: "all", activeEventsCount: 7),
        ]])
        let vm = HubTabsViewModel(fetchRelatedTags: FetchRelatedTagsUseCase(repository: repo))

        await vm.loadDynamicTabsIfNeeded()

        XCTAssertEqual(vm.tabs.filter { $0.id == "all" }.count, 1)
        // Server rank kept — not hoisted to the front.
        XCTAssertEqual(vm.tabs.map(\.id), ["politics", "all", "esports"])
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

// NextOutcome/Packages/Tests/MarketsPresentationTests/HubTabsViewModelTests.swift
import XCTest
import Foundation
import SharedDomain
@testable import MarketsPresentation
import MarketsDomain
import DesignSystem

@MainActor
final class HubTabsViewModelTests: XCTestCase {
    func test_init_seedsWithPinnedTabsOnly() {
        let vm = HubTabsViewModel(fetchTag: FetchTagUseCase(repository: SpyMarketRepository()))
        XCTAssertEqual(vm.tabs, HubTab.pinned)
    }

    func test_loadDynamicTabsIfNeeded_appendsResolvedTabsAfterPinned() async {
        let repo = SpyMarketRepository(tagsBySlug: [
            "crypto": Tag(id: "21", label: "Crypto", slug: "crypto"),
            "esports": Tag(id: "64", label: "Esports", slug: "esports"),
        ])
        let vm = HubTabsViewModel(fetchTag: FetchTagUseCase(repository: repo))

        await vm.loadDynamicTabsIfNeeded()

        XCTAssertEqual(Array(vm.tabs.prefix(HubTab.pinned.count)), HubTab.pinned)
        let dynamic = vm.tabs.dropFirst(HubTab.pinned.count)
        XCTAssertEqual(dynamic.map(\.id), ["crypto", "esports"])
        XCTAssertEqual(dynamic.map(\.tagID), ["21", "64"])
    }

    func test_loadDynamicTabsIfNeeded_skipsSlugsThatFailToResolve() async {
        let repo = SpyMarketRepository(
            tagsBySlug: ["crypto": Tag(id: "21", label: "Crypto", slug: "crypto")],
            failingSlugs: ["esports"]
        )
        let vm = HubTabsViewModel(fetchTag: FetchTagUseCase(repository: repo))

        await vm.loadDynamicTabsIfNeeded()

        XCTAssertTrue(vm.tabs.contains { $0.id == "crypto" })
        XCTAssertFalse(vm.tabs.contains { $0.id == "esports" })
    }

    func test_loadDynamicTabsIfNeeded_isIdempotent() async {
        let repo = SpyMarketRepository()
        let vm = HubTabsViewModel(fetchTag: FetchTagUseCase(repository: repo))

        await vm.loadDynamicTabsIfNeeded()
        await vm.loadDynamicTabsIfNeeded()

        let callCount = await repo.fetchTagCallCount
        XCTAssertEqual(callCount, HubTab.curatedAdditional.count)
    }
}

private actor SpyMarketRepository: MarketRepository {
    private let tagsBySlug: [String: Tag]
    private let failingSlugs: Set<String>
    private(set) var fetchTagCallCount = 0

    init(tagsBySlug: [String: Tag] = [:], failingSlugs: Set<String> = []) {
        self.tagsBySlug = tagsBySlug
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

    func fetchTag(slug: String) async throws -> Tag? {
        fetchTagCallCount += 1
        if failingSlugs.contains(slug) { throw URLError(.unknown) }
        return tagsBySlug[slug]
    }
}

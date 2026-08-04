import XCTest
import MarketsDomain
import SharedDomain
import DesignSystem
@testable import MarketsPresentation

/// How the curated featured rows compose with the volume-sorted feed. Mirrors the web's
/// pin behaviour: pinned on the default feed only, de-duplicated against the feed body.
@MainActor
final class FeaturedPinningTests: XCTestCase {
    private func event(_ id: String, tags: [String] = []) -> Event {
        Event(id: id, title: id, slug: id, markets: [], volume: 0, imageURL: nil,
              tags: tags.map { Tag(id: $0, label: $0, slug: $0) })
    }

    /// Repository returning a fixed feed page and a fixed featured list.
    private struct Repo: MarketRepository {
        let feed: [Event]
        let featured: [Event]
        func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> {
            Page(items: feed, nextCursor: nil)
        }
        func fetchFeaturedEvents(limit: Int) async throws -> [Event] { featured }
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

    private func makeVM(feed: [Event], featured: [Event]) -> EventListViewModel {
        let repo = Repo(feed: feed, featured: featured)
        return EventListViewModel(
            fetchEvents: FetchEventsUseCase(repository: repo),
            fetchRelatedTags: FetchRelatedTagsUseCase(repository: repo),
            searchEvents: SearchEventsUseCase(repository: repo),
            fetchFeaturedEvents: FetchFeaturedEventsUseCase(repository: repo)
        )
    }

    /// The headline case: curated rows lead, the volume feed follows.
    func test_featuredRowsArePinnedAboveTheFeed() async {
        let vm = makeVM(
            feed: [event("lol-match"), event("tennis-match")],
            featured: [event("fed"), event("iran")]
        )
        await vm.load()
        XCTAssertEqual(vm.visibleEvents.map(\.id), ["fed", "iran", "lol-match", "tennis-match"])
    }

    /// A featured event that also appears in the feed must render once, at the top.
    func test_pinnedEventIsRemovedFromTheFeedBody() async {
        let vm = makeVM(
            feed: [event("lol-match"), event("fed"), event("tennis-match")],
            featured: [event("fed")]
        )
        await vm.load()
        XCTAssertEqual(vm.visibleEvents.map(\.id), ["fed", "lol-match", "tennis-match"])
        XCTAssertEqual(vm.visibleEvents.filter { $0.id == "fed" }.count, 1)
    }

    /// Never pin more than the cap, however long the curated list is.
    func test_atMostThreeRowsArePinned() async {
        let vm = makeVM(
            feed: [event("feed-1")],
            featured: (1...10).map { event("f\($0)") }
        )
        await vm.load()
        XCTAssertEqual(vm.visibleEvents.map(\.id), ["f1", "f2", "f3", "feed-1"])
    }

    /// A curated ranking is meaningless once the user asks for a specific category.
    func test_selectingACategoryDropsThePinnedRows() async {
        let vm = makeVM(feed: [event("politics-1")], featured: [event("fed")])
        await vm.load()
        XCTAssertEqual(vm.visibleEvents.first?.id, "fed")

        await vm.apply(category: .politics)
        XCTAssertEqual(vm.visibleEvents.map(\.id), ["politics-1"])
    }

    /// Hide-toggles apply to pinned rows too — a hidden category must stay hidden even when
    /// an editor featured it.
    func test_hideFiltersAlsoApplyToPinnedRows() async {
        let vm = makeVM(
            feed: [event("news")],
            featured: [event("btc", tags: ["crypto"]), event("fed")]
        )
        await vm.load()
        XCTAssertEqual(vm.visibleEvents.map(\.id), ["btc", "fed", "news"])

        vm.toggleHideCrypto()
        XCTAssertEqual(vm.visibleEvents.map(\.id), ["fed", "news"])
    }

    /// The feed must survive a featured-list failure untouched.
    func test_featuredFailure_leavesFeedIntact() async {
        /// Repository whose featured call always throws.
        struct FailingFeatured: MarketRepository {
            func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> {
                Page(items: [Event(id: "a", title: "a", slug: "a", markets: [], volume: 0, imageURL: nil)], nextCursor: nil)
            }
            func fetchFeaturedEvents(limit: Int) async throws -> [Event] { throw CancellationError() }
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
        let repo = FailingFeatured()
        let vm = EventListViewModel(
            fetchEvents: FetchEventsUseCase(repository: repo),
            fetchRelatedTags: FetchRelatedTagsUseCase(repository: repo),
            searchEvents: SearchEventsUseCase(repository: repo),
            fetchFeaturedEvents: FetchFeaturedEventsUseCase(repository: repo)
        )
        await vm.load()
        XCTAssertEqual(vm.visibleEvents.map(\.id), ["a"])
        XCTAssertTrue(vm.featuredEvents.isEmpty)
    }
}

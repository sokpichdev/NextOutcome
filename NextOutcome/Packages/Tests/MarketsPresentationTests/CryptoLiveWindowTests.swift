import XCTest
import MarketsDomain
import SharedDomain
@testable import MarketsPresentation

/// The BTC Up/Down 5m card pinned above the Crypto hub — the card
/// `polymarket.com/crypto` leads with and ours was missing.
@MainActor
final class CryptoLiveWindowTests: XCTestCase {
    /// Repository serving a tag list and a by-slug lookup, recording which slug was asked for.
    private final class Repo: MarketRepository, @unchecked Sendable {
        let tagEvents: [Event]
        let bySlug: [String: Event]
        private(set) var requestedSlugs: [String] = []

        init(tagEvents: [Event] = [], bySlug: [String: Event] = [:]) {
            self.tagEvents = tagEvents
            self.bySlug = bySlug
        }

        func fetchAllEvents(tagID: String, status: EventStatus) async throws -> [Event] { tagEvents }
        func fetchEvent(slug: String) async throws -> Event {
            requestedSlugs.append(slug)
            guard let event = bySlug[slug] else { throw CancellationError() }
            return event
        }
        func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> { Page(items: [], nextCursor: nil) }
        func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
        func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
        func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
        func searchMarkets(query: String) async throws -> [Market] { [] }
        func fetchTags() async throws -> [Tag] { [] }
        func holders(conditionId: String) async throws -> [Holder] { [] }
        func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
        func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
    }

    /// An Up/Down event shaped like a real 5m window: zero volume, zero liquidity.
    private func upDownEvent(id: String, title: String = "Bitcoin Up or Down", resolved: Bool = false, ended: Bool? = nil) -> Event {
        let market = Market(
            id: id, question: title, slug: id,
            outcomes: [Outcome(id: "\(id)-up", title: "Up", price: 0.505),
                       Outcome(id: "\(id)-down", title: "Down", price: 0.495)],
            volume: 0, liquidity: 0, endDate: nil, isResolved: resolved, imageURL: nil
        )
        return Event(id: id, title: title, slug: id, markets: [market], volume: 0, imageURL: nil,
                     tags: [Tag(id: "21", label: "Crypto", slug: "crypto")], ended: ended)
    }

    /// 2026-08-03T13:42:07Z — inside the 13:40–13:45 window.
    private let insideWindow = Date(timeIntervalSince1970: 1_785_764_527)
    private let expectedSlug = "btc-updown-5m-1785764400"

    private func makeVM(_ repo: Repo, now: Date) -> CryptoHubViewModel {
        CryptoHubViewModel(
            fetchAllEvents: FetchAllEventsUseCase(repository: repo),
            fetchLiveWindow: FetchLiveWindowUseCase(repository: repo),
            now: { now }
        )
    }

    /// The headline case: the live window is fetched by its computed slug and pinned.
    func test_livePinIsFetchedByComputedSlugAndShown() async {
        let live = upDownEvent(id: expectedSlug)
        let repo = Repo(bySlug: [expectedSlug: live])
        let vm = makeVM(repo, now: insideWindow)

        await vm.loadLiveWindow()

        XCTAssertEqual(repo.requestedSlugs, [expectedSlug])
        XCTAssertEqual(vm.liveWindow?.id, expectedSlug)
        XCTAssertTrue(vm.showsLiveWindow)
    }

    /// A skipped grid slot is normal, not an error — the hub just renders no pin.
    func test_missingWindowIsNotAnError() async {
        let vm = makeVM(Repo(bySlug: [:]), now: insideWindow)
        await vm.loadLiveWindow()
        XCTAssertNil(vm.liveWindow)
        XCTAssertFalse(vm.showsLiveWindow)
    }

    /// A stale slot whose markets have settled must not render as though it were tradeable.
    func test_resolvedWindowIsRejected() async {
        let repo = Repo(bySlug: [expectedSlug: upDownEvent(id: expectedSlug, resolved: true)])
        let vm = makeVM(repo, now: insideWindow)
        await vm.loadLiveWindow()
        XCTAssertNil(vm.liveWindow)
    }

    /// Likewise for a window Gamma has flagged as ended.
    func test_endedWindowIsRejected() async {
        let repo = Repo(bySlug: [expectedSlug: upDownEvent(id: expectedSlug, ended: true)])
        let vm = makeVM(repo, now: insideWindow)
        await vm.loadLiveWindow()
        XCTAssertNil(vm.liveWindow)
    }

    /// The pin hides once the user asks for something it doesn't belong to.
    func test_pinHidesUnderConflictingFilters() async {
        let repo = Repo(bySlug: [expectedSlug: upDownEvent(id: expectedSlug)])
        let vm = makeVM(repo, now: insideWindow)
        await vm.loadLiveWindow()
        XCTAssertTrue(vm.showsLiveWindow)

        vm.selectedSubTab = .aboveBelow
        XCTAssertFalse(vm.showsLiveWindow, "an Up/Down pin has no business on the Above/Below tab")

        vm.selectedSubTab = .upDown
        XCTAssertTrue(vm.showsLiveWindow)

        vm.selectedTimeframe = .hourly
        XCTAssertFalse(vm.showsLiveWindow, "a 5-minute window is not an hourly one")

        vm.selectedTimeframe = .fiveMin
        XCTAssertTrue(vm.showsLiveWindow)

        vm.searchQuery = "ethereum"
        XCTAssertFalse(vm.showsLiveWindow, "search must not be contradicted by a pin")

        vm.searchQuery = "bitcoin"
        XCTAssertTrue(vm.showsLiveWindow)
    }

    /// If the tag list ever does contain the pinned window, it renders once, not twice.
    func test_pinnedWindowIsRemovedFromTheList() async {
        let live = upDownEvent(id: expectedSlug)
        let repo = Repo(tagEvents: [live, upDownEvent(id: "other")], bySlug: [expectedSlug: live])
        let vm = makeVM(repo, now: insideWindow)

        await vm.loadIfNeeded(tagID: "21")

        XCTAssertTrue(vm.showsLiveWindow)
        XCTAssertEqual(vm.visibleEvents.map(\.event.id), ["other"])
    }

    /// The refresh is scheduled on the window boundary, not a fixed interval — otherwise it
    /// drifts out of phase and shows a settled window as live.
    func test_refreshIsScheduledOnTheWindowBoundary() async {
        let vm = makeVM(Repo(), now: insideWindow)
        XCTAssertEqual(vm.nextLiveWindowBoundary, Date(timeIntervalSince1970: 1_785_764_700))
    }

    /// The hub must still load when the pinned window can't be resolved.
    func test_listLoadsEvenWhenThePinFails() async {
        let repo = Repo(tagEvents: [upDownEvent(id: "a")], bySlug: [:])
        let vm = makeVM(repo, now: insideWindow)

        await vm.loadIfNeeded(tagID: "21")

        XCTAssertEqual(vm.state, .loaded)
        XCTAssertEqual(vm.visibleEvents.map(\.event.id), ["a"])
        XCTAssertNil(vm.liveWindow)
    }
}

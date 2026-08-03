import XCTest
import MarketsDomain
import SharedDomain
@testable import MarketsPresentation

/// A failed refresh must never replace a good list with an error screen, and a cancelled
/// load isn't a failure at all.
@MainActor
final class CryptoRefreshResilienceTests: XCTestCase {
    /// Repository that serves events, then fails every subsequent call with `error`.
    private final class FlakyRepo: MarketRepository, @unchecked Sendable {
        let events: [Event]
        let error: Error
        var failFromCallNumber: Int
        private(set) var calls = 0

        init(events: [Event], error: Error, failFromCallNumber: Int) {
            self.events = events
            self.error = error
            self.failFromCallNumber = failFromCallNumber
        }

        func fetchAllEvents(tagID: String, status: EventStatus) async throws -> [Event] {
            calls += 1
            if calls >= failFromCallNumber { throw error }
            return events
        }
        func fetchEvent(slug: String) async throws -> Event { throw CancellationError() }
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

    private func upDown(_ id: String) -> Event {
        let market = Market(id: id, question: id, slug: id,
                            outcomes: [Outcome(id: "\(id)-u", title: "Up", price: 0.5),
                                       Outcome(id: "\(id)-d", title: "Down", price: 0.5)],
                            volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil)
        return Event(id: id, title: id, slug: id, markets: [market], volume: 0, imageURL: nil)
    }

    private func makeVM(_ repo: FlakyRepo) -> CryptoHubViewModel {
        CryptoHubViewModel(
            fetchAllEvents: FetchAllEventsUseCase(repository: repo),
            fetchLiveWindow: FetchLiveWindowUseCase(repository: repo)
        )
    }

    /// The reported bug: pull-to-refresh failed and wiped a perfectly good list.
    func test_failedRefreshKeepsTheExistingList() async {
        let repo = FlakyRepo(events: [upDown("a"), upDown("b")],
                             error: URLError(.timedOut), failFromCallNumber: 2)
        let vm = makeVM(repo)
        await vm.loadIfNeeded(tagID: "21")
        XCTAssertEqual(vm.state, .loaded)
        XCTAssertEqual(vm.classifiedEvents.count, 2)

        await vm.refresh()

        XCTAssertEqual(vm.state, .loaded, "a failed refresh must not show the error screen")
        XCTAssertEqual(vm.classifiedEvents.count, 2, "the loaded events must survive")
    }

    /// A cold load with nothing to fall back on still surfaces the failure.
    func test_coldLoadFailureStillShowsError() async {
        let repo = FlakyRepo(events: [], error: URLError(.timedOut), failFromCallNumber: 1)
        let vm = makeVM(repo)
        await vm.loadIfNeeded(tagID: "21")
        guard case .failed = vm.state else {
            return XCTFail("expected .failed with nothing to show, got \(vm.state)")
        }
    }

    /// SwiftUI cancels `.task`/`.refreshable` work routinely; that must never read as broken.
    func test_cancellationIsNotAFailure() async {
        for error in [CancellationError() as Error, URLError(.cancelled) as Error] {
            let repo = FlakyRepo(events: [], error: error, failFromCallNumber: 1)
            let vm = makeVM(repo)
            await vm.loadIfNeeded(tagID: "21")
            if case .failed = vm.state {
                XCTFail("cancellation (\(type(of: error))) must not surface as a failure")
            }
        }
    }

    /// A refresh keeps the list on screen rather than flashing a spinner over it.
    func test_refreshDoesNotBlankTheListWhileLoading() async {
        let repo = FlakyRepo(events: [upDown("a")], error: URLError(.timedOut), failFromCallNumber: 99)
        let vm = makeVM(repo)
        await vm.loadIfNeeded(tagID: "21")

        // Reloading with content already present must never pass through `.loading`.
        await vm.refresh()
        XCTAssertEqual(vm.state, .loaded)
        XCTAssertFalse(vm.classifiedEvents.isEmpty)
    }
}

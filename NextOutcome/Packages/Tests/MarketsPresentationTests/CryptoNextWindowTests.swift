//
//  CryptoNextWindowTests.swift
//  NextOutcome
//

import XCTest
import MarketsDomain
import SharedDomain
@testable import MarketsPresentation

/// Advancing the live screen to the next window in place, so a settled window doesn't send
/// the user back to the hub and in again.
@MainActor
final class CryptoNextWindowTests: XCTestCase {
    /// By-slug repository, recording what was asked for.
    private final class Repo: MarketRepository, @unchecked Sendable {
        let bySlug: [String: Event]
        private(set) var requestedSlugs: [String] = []

        init(bySlug: [String: Event] = [:]) { self.bySlug = bySlug }

        func fetchEvent(slug: String) async throws -> Event {
            requestedSlugs.append(slug)
            guard let event = bySlug[slug] else { throw CancellationError() }
            return event
        }
        func fetchAllEvents(tagID: String, status: EventStatus) async throws -> [Event] { [] }
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

    /// An Up/Down window event whose slug is the grid slug, as Gamma serves it.
    private func window(slug: String, coin: Tag = Tag(id: "1", label: "Bitcoin", slug: "bitcoin")) -> Event {
        let market = Market(
            id: slug, question: "Bitcoin Up or Down", slug: slug,
            outcomes: [Outcome(id: "\(slug)-up", title: "Up", price: 0.5),
                       Outcome(id: "\(slug)-down", title: "Down", price: 0.5)],
            volume: 0, liquidity: 0, endDate: Date(timeIntervalSince1970: 1_787_069_700),
            isResolved: false, imageURL: nil
        )
        return Event(id: slug, title: "Bitcoin Up or Down", slug: slug, markets: [market],
                     volume: 0, imageURL: nil, tags: [coin])
    }

    /// The window the user is sitting on, closed: 12:05–12:10.
    private let settledSlug = "btc-updown-5m-1787069100"
    /// The one that is live once it closes: 12:10–12:15.
    private let liveSlug = "btc-updown-5m-1787069400"
    /// 12:10:30 — just inside the live window.
    private let afterBoundary = Date(timeIntervalSince1970: 1_787_069_430)

    private func makeVM(_ repo: Repo, now: Date) -> CryptoHubViewModel {
        CryptoHubViewModel(
            fetchAllEvents: FetchAllEventsUseCase(repository: repo),
            fetchLiveWindow: FetchLiveWindowUseCase(repository: repo),
            now: { now }
        )
    }

    /// The target the live screen was opened with.
    private func settledTarget() -> CryptoUpDownNavigationTarget {
        guard let target = CryptoUpDownNavigationTarget(event: window(slug: settledSlug)) else {
            preconditionFailure("fixture must produce a target")
        }
        return target
    }

    func test_nextWindow_resolvesTheLiveWindowOfTheSameSeries() async {
        let repo = Repo(bySlug: [liveSlug: window(slug: liveSlug)])
        let vm = makeVM(repo, now: afterBoundary)

        let next = await vm.nextWindow(after: settledTarget())

        XCTAssertEqual(repo.requestedSlugs, [liveSlug],
                       "the series must come from the window on screen, not a hardcoded one")
        XCTAssertEqual(next?.eventID, liveSlug)
        XCTAssertEqual(next?.assetID, "\(liveSlug)-up")
    }

    /// A daily ETH window must advance to the next ETH daily window — the hub's own pinned
    /// series is BTC 5m, and using it here would teleport the user to a different market.
    func test_nextWindow_staysInsideANonBitcoinSeries() async {
        let ethSlug = "eth-updown-1d-1787000000"
        let ethEvent = window(slug: ethSlug, coin: Tag(id: "2", label: "Ethereum", slug: "ethereum"))
        guard let ethTarget = CryptoUpDownNavigationTarget(event: ethEvent) else {
            return XCTFail("fixture must produce a target")
        }
        let repo = Repo()
        let vm = makeVM(repo, now: afterBoundary)

        _ = await vm.nextWindow(after: ethTarget)

        XCTAssertEqual(repo.requestedSlugs.first?.hasPrefix("eth-updown-1d-"), true,
                       "an ETH window must ask for an ETH window")
    }

    /// At the boundary Gamma occasionally can't serve the new window yet. That's a "not
    /// ready", not a destination — the screen keeps its button so the user can tap again.
    func test_nextWindow_isNilWhenTheNewWindowIsNotServedYet() async {
        let vm = makeVM(Repo(bySlug: [:]), now: afterBoundary)

        let next = await vm.nextWindow(after: settledTarget())

        XCTAssertNil(next)
    }

    /// Tapped a moment early — the grid hasn't rolled and the "live" window is the settled
    /// one already on screen. Advancing into it would look like a broken refresh.
    func test_nextWindow_isNilWhenTheLiveWindowIsStillTheCurrentOne() async {
        let repo = Repo(bySlug: [settledSlug: window(slug: settledSlug)])
        // 12:07 — still inside the window the user is looking at.
        let vm = makeVM(repo, now: Date(timeIntervalSince1970: 1_787_069_220))

        let next = await vm.nextWindow(after: settledTarget())

        XCTAssertNil(next)
    }

    // MARK: Target from an event

    func test_target_derivesSymbolAndTitleFromTheEvent() {
        let target = CryptoUpDownNavigationTarget(
            event: window(slug: liveSlug, coin: Tag(id: "2", label: "Ethereum", slug: "ethereum"))
        )

        XCTAssertEqual(target?.symbol, "ETH")
        XCTAssertEqual(target?.title, "Bitcoin Up or Down")
    }

    /// No "Up" outcome means nothing to chart or trade, so there is no target to push.
    func test_target_isNilWithoutAnUpOutcome() {
        let market = Market(
            id: "m", question: "?", slug: liveSlug,
            outcomes: [Outcome(id: "a", title: "Above", price: 0.5)],
            volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil
        )
        let event = Event(id: "e", title: "t", slug: liveSlug, markets: [market],
                          volume: 0, imageURL: nil, tags: [])

        XCTAssertNil(CryptoUpDownNavigationTarget(event: event))
    }
}

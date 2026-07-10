import XCTest
import Foundation
@testable import MarketsPresentation
import MarketsDomain
import SharedDomain

@MainActor
final class CryptoHubViewModelTests: XCTestCase {
    private func event(id: String, title: String, volume: Decimal = 0, markets: [Market] = []) -> Event {
        Event(id: id, title: title, slug: id, markets: markets, volume: volume, imageURL: nil)
    }

    private func upDownMarket(id: String, endDate: Date? = nil) -> Market {
        Market(
            id: id, question: "Q", slug: id,
            outcomes: [
                Outcome(id: "\(id)-up", title: "Up", price: Decimal(0.5)),
                Outcome(id: "\(id)-down", title: "Down", price: Decimal(0.5)),
            ],
            volume: 0, liquidity: 0, endDate: endDate, isResolved: false, imageURL: nil
        )
    }

    private func aboveBelowMarket(id: String, groupItemTitle: String) -> Market {
        Market(
            id: id, question: "Q", slug: id, outcomes: [],
            volume: 0, liquidity: 0, endDate: nil, isResolved: false,
            imageURL: nil, groupItemTitle: groupItemTitle
        )
    }

    private func makeVM(events: [Event]) -> (CryptoHubViewModel, CryptoFakeRepository) {
        let repo = CryptoFakeRepository()
        repo.events = events
        let vm = CryptoHubViewModel(fetchAllEvents: FetchAllEventsUseCase(repository: repo))
        return (vm, repo)
    }

    func test_loadIfNeeded_classifiesAndExcludesOther() async {
        let upDown = event(id: "1", title: "BTC Up or Down 5m", markets: [upDownMarket(id: "m1")])
        let other = event(id: "2", title: "Random crypto thing", markets: [])
        let (vm, _) = makeVM(events: [upDown, other])

        await vm.loadIfNeeded(tagID: "crypto-tag")

        XCTAssertEqual(vm.state, .loaded)
        XCTAssertEqual(vm.classifiedEvents.map(\.event.id), ["1"])
    }

    func test_loadIfNeeded_isIdempotent_forSameTagID() async {
        let (vm, repo) = makeVM(events: [event(id: "1", title: "BTC Up or Down 5m", markets: [upDownMarket(id: "m1")])])

        await vm.loadIfNeeded(tagID: "crypto-tag")
        repo.events = []
        await vm.loadIfNeeded(tagID: "crypto-tag")

        XCTAssertEqual(vm.classifiedEvents.map(\.event.id), ["1"]) // second call was a no-op
    }

    func test_visibleEvents_filtersBySelectedSubTab() async {
        let upDown = event(id: "1", title: "BTC Up or Down 5m", markets: [upDownMarket(id: "m1")])
        let aboveBelow = event(id: "2", title: "Bitcoin above ___ on July 10?", markets: [aboveBelowMarket(id: "m2", groupItemTitle: "52,000")])
        let (vm, _) = makeVM(events: [upDown, aboveBelow])
        await vm.loadIfNeeded(tagID: "crypto-tag")

        vm.selectedSubTab = .upDown
        XCTAssertEqual(vm.visibleEvents.map(\.event.id), ["1"])

        vm.selectedSubTab = .aboveBelow
        XCTAssertEqual(vm.visibleEvents.map(\.event.id), ["2"])

        vm.selectedSubTab = .all
        XCTAssertEqual(Set(vm.visibleEvents.map(\.event.id)), Set(["1", "2"]))
    }

    func test_visibleEvents_sortsByVolume_descending() async {
        let low = event(id: "low", title: "BTC Up or Down 5m", volume: 10, markets: [upDownMarket(id: "m1")])
        let high = event(id: "high", title: "ETH Up or Down 5m", volume: 100, markets: [upDownMarket(id: "m2")])
        let (vm, _) = makeVM(events: [low, high])
        await vm.loadIfNeeded(tagID: "crypto-tag")

        vm.sortOption = .volume
        XCTAssertEqual(vm.visibleEvents.map(\.event.id), ["high", "low"])
    }

    func test_visibleEvents_sortsByEndingSoon_noEndDateSortsLast() async {
        let now = Date(timeIntervalSince1970: 1_782_216_000)
        let soon = event(id: "soon", title: "BTC Up or Down 5m", markets: [upDownMarket(id: "m1", endDate: now.addingTimeInterval(60))])
        let later = event(id: "later", title: "ETH Up or Down 5m", markets: [upDownMarket(id: "m2", endDate: now.addingTimeInterval(3600))])
        let never = event(id: "never", title: "XRP Up or Down 5m", markets: [upDownMarket(id: "m3", endDate: nil)])
        let (vm, _) = makeVM(events: [never, later, soon])
        await vm.loadIfNeeded(tagID: "crypto-tag")

        vm.sortOption = .endingSoon
        XCTAssertEqual(vm.visibleEvents.map(\.event.id), ["soon", "later", "never"])
    }

    func test_visibleEvents_filtersByPeriod_keywordMatch() async {
        let daily = event(id: "daily", title: "BTC Up or Down Daily", markets: [upDownMarket(id: "m1")])
        let fiveMin = event(id: "5m", title: "BTC Up or Down 5m", markets: [upDownMarket(id: "m2")])
        let (vm, _) = makeVM(events: [daily, fiveMin])
        await vm.loadIfNeeded(tagID: "crypto-tag")

        vm.period = .daily
        XCTAssertEqual(vm.visibleEvents.map(\.event.id), ["daily"])

        vm.period = .all
        XCTAssertEqual(Set(vm.visibleEvents.map(\.event.id)), Set(["daily", "5m"]))
    }

    func test_refresh_beforeFirstLoad_isNoOp() async {
        let (vm, _) = makeVM(events: [])
        await vm.refresh()
        XCTAssertEqual(vm.state, .idle)
    }
}

private final class CryptoFakeRepository: MarketRepository, @unchecked Sendable {
    var events: [Event] = []

    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> {
        Page(items: [], nextCursor: nil)
    }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchAllEvents(tagID: String, status: EventStatus) async throws -> [Event] { events }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
    func fetchEvent(slug: String) async throws -> Event { throw URLError(.resourceUnavailable) }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
}

import XCTest
import Foundation
@testable import MarketsPresentation
import MarketsDomain
import SharedDomain

@MainActor
final class CryptoHubViewModelTests: XCTestCase {
    private func event(
        id: String, title: String, volume: Decimal = 0, markets: [Market] = [], recurrence: String? = nil,
        volume24hr: Decimal = 0, liquidity: Decimal = 0, competitive: Double? = nil, creationDate: Date? = nil
    ) -> Event {
        Event(
            id: id, title: title, slug: id, markets: markets, volume: volume, imageURL: nil,
            recurrence: recurrence, volume24hr: volume24hr, liquidity: liquidity,
            competitive: competitive, creationDate: creationDate
        )
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

    private func makeVM(
        events: [Event], now: @escaping () -> Date = { Date() }
    ) -> (CryptoHubViewModel, CryptoFakeRepository) {
        let repo = CryptoFakeRepository()
        repo.events = events
        let vm = CryptoHubViewModel(fetchAllEvents: FetchAllEventsUseCase(repository: repo), now: now)
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

    /// Regression: Polymarket sometimes returns dead ephemeral crypto windows as
    /// `closed:false, active:true` (e.g. an "Ethereum Up or Down — Dec 19" 5-min event whose
    /// window ended months ago). Opening one fires `/api/crypto/*` with a stale timestamp and
    /// 400s ("Timestamp too old for Chainlink API"). The hub must drop any crypto window whose
    /// latest market end is already in the past, regardless of the API's `closed` flag. Events
    /// with no end date are kept (can't tell they're expired).
    func test_loadIfNeeded_excludesExpiredCryptoWindows() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let live = event(id: "live", title: "BTC Up or Down 5m", markets: [upDownMarket(id: "m1", endDate: now.addingTimeInterval(120))])
        let expired = event(id: "expired", title: "ETH Up or Down 5m", markets: [upDownMarket(id: "m2", endDate: now.addingTimeInterval(-3600))])
        let noEnd = event(id: "noEnd", title: "SOL Up or Down 5m", markets: [upDownMarket(id: "m3", endDate: nil)])
        let (vm, _) = makeVM(events: [live, expired, noEnd], now: { now })

        await vm.loadIfNeeded(tagID: "crypto-tag")

        XCTAssertEqual(
            Set(vm.classifiedEvents.map(\.event.id)), Set(["live", "noEnd"]),
            "an expired crypto window must be excluded even when the API reports it as active/open"
        )
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

    func test_visibleEvents_sortsByTotalVolume_descending() async {
        let low = event(id: "low", title: "BTC Up or Down 5m", volume: 10, markets: [upDownMarket(id: "m1")])
        let high = event(id: "high", title: "ETH Up or Down 5m", volume: 100, markets: [upDownMarket(id: "m2")])
        let (vm, _) = makeVM(events: [low, high])
        await vm.loadIfNeeded(tagID: "crypto-tag")

        vm.sortOption = .totalVolume
        XCTAssertEqual(vm.visibleEvents.map(\.event.id), ["high", "low"])
    }

    func test_visibleEvents_sortsByVolume24hr_descending() async {
        let low = event(id: "low", title: "BTC Up or Down 5m", markets: [upDownMarket(id: "m1")], volume24hr: 10)
        let high = event(id: "high", title: "ETH Up or Down 5m", markets: [upDownMarket(id: "m2")], volume24hr: 100)
        let (vm, _) = makeVM(events: [low, high])
        await vm.loadIfNeeded(tagID: "crypto-tag")

        vm.sortOption = .volume24hr
        XCTAssertEqual(vm.visibleEvents.map(\.event.id), ["high", "low"])
    }

    func test_visibleEvents_sortsByLiquidity_descending() async {
        let low = event(id: "low", title: "BTC Up or Down 5m", markets: [upDownMarket(id: "m1")], liquidity: 10)
        let high = event(id: "high", title: "ETH Up or Down 5m", markets: [upDownMarket(id: "m2")], liquidity: 100)
        let (vm, _) = makeVM(events: [low, high])
        await vm.loadIfNeeded(tagID: "crypto-tag")

        vm.sortOption = .liquidity
        XCTAssertEqual(vm.visibleEvents.map(\.event.id), ["high", "low"])
    }

    func test_visibleEvents_sortsByNewest_descending_noCreationDateSortsLast() async {
        let now = Date(timeIntervalSince1970: 1_782_216_000)
        let newer = event(id: "newer", title: "BTC Up or Down 5m", markets: [upDownMarket(id: "m1")], creationDate: now)
        let older = event(id: "older", title: "ETH Up or Down 5m", markets: [upDownMarket(id: "m2")], creationDate: now.addingTimeInterval(-3600))
        let unknown = event(id: "unknown", title: "XRP Up or Down 5m", markets: [upDownMarket(id: "m3")], creationDate: nil)
        let (vm, _) = makeVM(events: [unknown, older, newer])
        await vm.loadIfNeeded(tagID: "crypto-tag")

        vm.sortOption = .newest
        XCTAssertEqual(vm.visibleEvents.map(\.event.id), ["newer", "older", "unknown"])
    }

    func test_visibleEvents_sortsByCompetitive_descending_noScoreSortsLast() async {
        let veryCompetitive = event(id: "very", title: "BTC Up or Down 5m", markets: [upDownMarket(id: "m1")], competitive: 0.99)
        let lessCompetitive = event(id: "less", title: "ETH Up or Down 5m", markets: [upDownMarket(id: "m2")], competitive: 0.5)
        let unscored = event(id: "unscored", title: "XRP Up or Down 5m", markets: [upDownMarket(id: "m3")], competitive: nil)
        let (vm, _) = makeVM(events: [unscored, lessCompetitive, veryCompetitive])
        await vm.loadIfNeeded(tagID: "crypto-tag")

        vm.sortOption = .competitive
        XCTAssertEqual(vm.visibleEvents.map(\.event.id), ["very", "less", "unscored"])
    }

    func test_visibleEvents_sortsByEndingSoon_noEndDateSortsLast() async {
        let now = Date(timeIntervalSince1970: 1_782_216_000)
        let soon = event(id: "soon", title: "BTC Up or Down 5m", markets: [upDownMarket(id: "m1", endDate: now.addingTimeInterval(60))])
        let later = event(id: "later", title: "ETH Up or Down 5m", markets: [upDownMarket(id: "m2", endDate: now.addingTimeInterval(3600))])
        let never = event(id: "never", title: "XRP Up or Down 5m", markets: [upDownMarket(id: "m3", endDate: nil)])
        // Anchor the clock before these end dates so the expiry filter keeps them all — this
        // test is about sort order, not expiry.
        let (vm, _) = makeVM(events: [never, later, soon], now: { now })
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

    /// Pull-to-refresh cancels its own in-flight request under view churn (`NSURLErrorCancelled`,
    /// −999). That's benign — a cancelled refresh must keep the already-loaded content, not flash
    /// the "Couldn't load Crypto" error over 200+ good events.
    func test_refresh_whenRequestCancelled_keepsLoadedContent() async {
        let live = event(id: "1", title: "BTC Up or Down 5m", markets: [upDownMarket(id: "m1")])
        let (vm, repo) = makeVM(events: [live])
        await vm.loadIfNeeded(tagID: "crypto-tag")
        XCTAssertEqual(vm.state, .loaded)

        repo.errorToThrow = URLError(.cancelled)
        await vm.refresh()

        XCTAssertEqual(vm.state, .loaded, "a cancelled refresh must not surface an error")
        XCTAssertEqual(vm.classifiedEvents.map(\.event.id), ["1"], "existing content must be kept")
    }

    /// A genuinely failed refresh (not just cancelled) must also keep the existing content
    /// rather than blanking to an error screen when we already have data to show.
    func test_refresh_whenRequestFails_withExistingData_keepsContent() async {
        let live = event(id: "1", title: "BTC Up or Down 5m", markets: [upDownMarket(id: "m1")])
        let (vm, repo) = makeVM(events: [live])
        await vm.loadIfNeeded(tagID: "crypto-tag")

        repo.errorToThrow = URLError(.timedOut)
        await vm.refresh()

        XCTAssertEqual(vm.state, .loaded)
        XCTAssertEqual(vm.classifiedEvents.map(\.event.id), ["1"])
    }

    /// A failed *initial* load (no data yet) must still surface the error screen.
    func test_initialLoad_failure_showsError() async {
        let (vm, repo) = makeVM(events: [])
        repo.errorToThrow = URLError(.notConnectedToInternet)
        await vm.loadIfNeeded(tagID: "crypto-tag")
        XCTAssertEqual(vm.state, .failed("Couldn't load Crypto. Pull to refresh."))
    }

    func test_timeframeCount_countsClassifiedEventsPerBucket() async {
        let fiveMin = event(id: "5m", title: "BTC Up or Down 5m", markets: [upDownMarket(id: "m1")], recurrence: "btc-up-or-down-5m")
        let fifteenMin = event(id: "15m", title: "ETH Up or Down 15m", markets: [upDownMarket(id: "m2")], recurrence: "eth-up-or-down-15m")
        let hourly = event(id: "hourly", title: "SOL Up or Down Hourly", markets: [upDownMarket(id: "m3")], recurrence: "sol-up-or-down-hourly")
        let fourHour = event(id: "4h", title: "BTC Up or Down 4h", markets: [upDownMarket(id: "m4")], recurrence: "btc-up-or-down-4h")
        let (vm, _) = makeVM(events: [fiveMin, fifteenMin, hourly, fourHour])
        await vm.loadIfNeeded(tagID: "crypto-tag")

        XCTAssertEqual(vm.timeframeCount(for: .all), 4)
        XCTAssertEqual(vm.timeframeCount(for: .fiveMin), 1)
        XCTAssertEqual(vm.timeframeCount(for: .fifteenMin), 1)
        XCTAssertEqual(vm.timeframeCount(for: .hourly), 1)
        // "4h" doesn't match any of the 3 specific buckets, only counts under .all.
    }

    func test_visibleEvents_filtersBySelectedTimeframe() async {
        let fiveMin = event(id: "5m", title: "BTC Up or Down 5m", markets: [upDownMarket(id: "m1")], recurrence: "btc-up-or-down-5m")
        let hourly = event(id: "hourly", title: "SOL Up or Down Hourly", markets: [upDownMarket(id: "m2")], recurrence: "sol-up-or-down-hourly")
        let (vm, _) = makeVM(events: [fiveMin, hourly])
        await vm.loadIfNeeded(tagID: "crypto-tag")

        vm.selectedTimeframe = .fiveMin
        XCTAssertEqual(vm.visibleEvents.map(\.event.id), ["5m"])

        vm.selectedTimeframe = .all
        XCTAssertEqual(Set(vm.visibleEvents.map(\.event.id)), Set(["5m", "hourly"]))
    }

    func test_visibleEvents_filtersBySearchQuery_caseInsensitive() async {
        let bitcoin = event(id: "btc", title: "BTC Up or Down 5m", markets: [upDownMarket(id: "m1")])
        let ethereum = event(id: "eth", title: "ETH Up or Down 5m", markets: [upDownMarket(id: "m2")])
        let (vm, _) = makeVM(events: [bitcoin, ethereum])
        await vm.loadIfNeeded(tagID: "crypto-tag")

        vm.searchQuery = "btc"
        XCTAssertEqual(vm.visibleEvents.map(\.event.id), ["btc"])

        vm.searchQuery = ""
        XCTAssertEqual(Set(vm.visibleEvents.map(\.event.id)), Set(["btc", "eth"]))
    }
}

private final class CryptoFakeRepository: MarketRepository, @unchecked Sendable {
    var events: [Event] = []
    /// When set, `fetchAllEvents` throws it — lets tests simulate a cancelled/failed refresh.
    var errorToThrow: Error?

    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> {
        Page(items: [], nextCursor: nil)
    }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchAllEvents(tagID: String, status: EventStatus) async throws -> [Event] {
        if let errorToThrow { throw errorToThrow }
        return events
    }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
    func fetchEvent(slug: String) async throws -> Event { throw URLError(.resourceUnavailable) }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
}

import XCTest
import MarketsDomain
@testable import MarketsPresentation

/// Collapsing pre-created cadence windows down to one card per series — the difference
/// between the chips reading `5 Min 132` and `5 Min 7`.
/// See `docs/polymarket-crypto-hub-gaps.md` §3.
final class RecurringWindowCollapseTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_785_764_400)  // 2026-08-03T13:40:00Z

    private func window(_ id: String, series: String?, endsIn seconds: TimeInterval?) -> (event: Event, kind: CryptoMarketKind) {
        let event = Event(
            id: id, title: id, slug: id,
            markets: [Market(id: id, question: id, slug: id,
                             outcomes: [Outcome(id: "\(id)-u", title: "Up", price: 0.5),
                                        Outcome(id: "\(id)-d", title: "Down", price: 0.5)],
                             volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil)],
            volume: 0, imageURL: nil, recurrence: series,
            endDate: seconds.map { now.addingTimeInterval($0) }
        )
        return (event, .upDown)
    }

    /// The headline case: ~24h of pre-created windows becomes one card.
    func test_keepsOnlyTheEarliestOpenWindowPerSeries() {
        let items = (1...20).map { window("btc-\($0)", series: "btc-up-or-down-5m", endsIn: Double($0) * 300) }
        let collapsed = RecurringWindowCollapse.collapse(items, asOf: now)
        XCTAssertEqual(collapsed.map(\.event.id), ["btc-1"])
    }

    /// Each series keeps its own window — collapsing must not merge assets together.
    func test_collapsesPerSeriesNotGlobally() {
        let items = [
            window("btc-late", series: "btc-up-or-down-5m", endsIn: 900),
            window("btc-next", series: "btc-up-or-down-5m", endsIn: 300),
            window("eth-late", series: "eth-up-or-down-5m", endsIn: 1200),
            window("eth-next", series: "eth-up-or-down-5m", endsIn: 600),
        ]
        let collapsed = RecurringWindowCollapse.collapse(items, asOf: now)
        XCTAssertEqual(Set(collapsed.map(\.event.id)), ["btc-next", "eth-next"])
    }

    /// Different cadences of the same asset are different series and both survive — that's
    /// what makes the chips read 7 / 7 / 7 rather than 7 total.
    func test_differentCadencesOfSameAssetBothSurvive() {
        let items = [
            window("btc-5m", series: "btc-up-or-down-5m", endsIn: 300),
            window("btc-15m", series: "btc-up-or-down-15m", endsIn: 900),
            window("btc-hourly", series: "btc-up-or-down-hourly", endsIn: 3600),
        ]
        let collapsed = RecurringWindowCollapse.collapse(items, asOf: now)
        XCTAssertEqual(collapsed.count, 3)
    }

    /// Already-closed windows are never the answer.
    func test_closedWindowsAreDropped() {
        let items = [
            window("past", series: "btc-up-or-down-5m", endsIn: -300),
            window("live", series: "btc-up-or-down-5m", endsIn: 120),
        ]
        XCTAssertEqual(RecurringWindowCollapse.collapse(items, asOf: now).map(\.event.id), ["live"])
    }

    /// A series with nothing open left contributes no card rather than an expired one.
    func test_seriesWithOnlyClosedWindowsContributesNothing() {
        let items = [window("past", series: "btc-up-or-down-5m", endsIn: -300)]
        XCTAssertTrue(RecurringWindowCollapse.collapse(items, asOf: now).isEmpty)
    }

    /// The load-bearing safety property: `recurrence` is `series[0].slug`, which for esports
    /// is a *category* (`league-of-legends`), not a repeating window. Collapsing those would
    /// erase the Esports hub.
    func test_nonCadenceSeriesAreNeverCollapsed() {
        let items = [
            window("lol-1", series: "league-of-legends", endsIn: 3600),
            window("lol-2", series: "league-of-legends", endsIn: 7200),
            window("lol-3", series: "league-of-legends", endsIn: -60),
        ]
        let collapsed = RecurringWindowCollapse.collapse(items, asOf: now)
        XCTAssertEqual(collapsed.count, 3, "a category series is not a recurring window")
    }

    /// One-off markets have no series at all and must pass straight through.
    func test_eventsWithoutASeriesPassThrough() {
        let items = [window("fed", series: nil, endsIn: -99_999)]
        XCTAssertEqual(RecurringWindowCollapse.collapse(items, asOf: now).map(\.event.id), ["fed"])
    }

    /// A cadence event with no end date can't be ordered; keep it rather than lose it.
    func test_cadenceEventWithoutEndDateIsKept() {
        let items = [
            window("no-end", series: "btc-up-or-down-daily", endsIn: nil),
            window("dated", series: "btc-up-or-down-daily", endsIn: 300),
        ]
        XCTAssertEqual(Set(RecurringWindowCollapse.collapse(items, asOf: now).map(\.event.id)),
                       ["no-end", "dated"])
    }

    /// Order is preserved so the caller's own sort stays deterministic.
    func test_originalOrderIsPreserved() {
        let items = [
            window("a", series: nil, endsIn: nil),
            window("btc", series: "btc-up-or-down-5m", endsIn: 300),
            window("z", series: nil, endsIn: nil),
        ]
        XCTAssertEqual(RecurringWindowCollapse.collapse(items, asOf: now).map(\.event.id), ["a", "btc", "z"])
    }

    /// Every suffix the hub's timeframe chips key on must be recognised, or the two disagree.
    func test_allCadenceSuffixesAreRecognised() {
        for suffix in ["-5m", "-15m", "-hourly", "-4h", "-daily"] {
            XCTAssertTrue(RecurringWindowCollapse.isCadenceSeries("btc-up-or-down\(suffix)"), suffix)
        }
        XCTAssertFalse(RecurringWindowCollapse.isCadenceSeries("league-of-legends"))
        XCTAssertFalse(RecurringWindowCollapse.isCadenceSeries(nil))
    }
}

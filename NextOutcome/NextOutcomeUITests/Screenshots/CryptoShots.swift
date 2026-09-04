//
//  CryptoShots.swift
//  NextOutcomeUITests
//
//  Crypto hub, the live chart screen, and the order book.
//
//  Every predicate here was checked against the actual view source
//  (`CryptoHubView.swift`, `CryptoUpDownCard.swift`, `BTCLiveView.swift`,
//  `BTCLiveSections.swift`, `OrderbookView.swift`) rather than assumed from the v1 UI —
//  see the per-test comments below for what changed and why.
//

import XCTest

final class CryptoShots: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Launches straight into the Crypto hub.
    private func cryptoHub() -> XCUIApplication {
        let app = launchForScreenshots(preselecting: "crypto", tagID: CryptoTag.id)
        settle(app, timeout: UIWait.firstLoad)
        return app
    }

    /// Opens the first crypto Up/Down market in the hub — either the pinned live window
    /// card (`CryptoHubView.liveWindowCard`) or the first matching card further down the
    /// feed, whichever the accessibility tree finds first.
    ///
    /// `CryptoUpDownCard` has no "Bitcoin" text anywhere in its body — the brief's
    /// `buttons CONTAINS "Bitcoin"` predicate never matches. The card's headline is
    /// `event.seriesTitle ?? event.title` (e.g. "BTC Up or Down 5m", "ETH Up or Down 15m"),
    /// rendered as a plain `Text`, not composed into a button label — so this matches a
    /// static text containing "Up or Down" instead, then taps it: the whole `DSCard` sits
    /// inside a `NavigationLink`, so a tap anywhere on it (including the plain Text) still
    /// activates the link. This is the exact technique `CryptoUITests.testBTCLiveCandleChart…`
    /// already uses successfully against this same screen.
    private func openFirstMarket(in app: XCUIApplication) {
        let card = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Up or Down")).firstMatch
        XCTAssertTrue(card.waitForHittable(timeout: UIWait.load), "No crypto Up/Down market card")
        card.tap()
        settle(app)
    }

    /// A stable, asset-independent anchor near the very top of the live screen
    /// (`BTCLiveHeaderSection.priceRow`'s "Price To Beat" caption) — unlike the chart's own
    /// title (`viewModel.chartTitle`, e.g. "BTC 5m" vs "ETH 5m"), this text never changes
    /// with which coin's window got opened, so scroll-position checks below don't need to
    /// know the asset. `BTCLiveView.body` is a plain `VStack`, not a `LazyVStack`, so this
    /// element stays in the accessibility tree (with a real, if off-screen, frame) once
    /// scrolled past rather than being torn down.
    private func priceToBeatCaption(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts["Price To Beat"]
    }

    func test_cryptoHub() {
        let app = cryptoHub()
        capture("crypto_hub", of: app)
    }

    /// The brief's "Hourly" predicate for the hub's tab strip doesn't exist: the hub has
    /// two chip rows — a timeframe row (`CryptoHubView.timeframeChipRow`: "All" / "5 Min" /
    /// "15 Min" / "1 Hour" / "•••More") and a sub-tab row (All / Up-Down / Above-Below /
    /// Price Range / Hit Price) — and neither renders a chip literally titled "Hourly".
    ///
    /// `CryptoUITests.testCryptoHubLoads` matches this same chip with an *exact*
    /// `app.buttons["1 Hour"]`, but that timed out here (`waitForHittable` never went true).
    /// `timeframeChip` composes an `Image(systemName: "clock")` + `Text("1 Hour")` +
    /// `Text(count)` into one `HStack` label — the same pattern `SportsShots.sportsChip`
    /// documents for the Sports nav bar's chips, where the glyph and the live count fold
    /// into the accessibility label too (e.g. "clock, 1 Hour, 42"), so an exact match never
    /// hits. Matched by substring instead, the same fix `SportsShots` already applied for
    /// that identical composition.
    ///
    /// Filtering to `.hourly` (default is `.all`) also changes `visibleEvents`, so the
    /// capture is a real, distinct screen rather than a cosmetic chip-selected duplicate of
    /// `crypto_hub`.
    func test_cryptoHubTabs() {
        let app = cryptoHub()
        let hourly = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "1 Hour")).firstMatch
        XCTAssertTrue(hourly.waitForHittable(timeout: UIWait.ui), "No '1 Hour' timeframe chip")
        hourly.tap()
        settle(app)
        capture("crypto_hub_tabs", of: app)
    }

    func test_cryptoLive() {
        let app = cryptoHub()
        openFirstMarket(in: app)
        capture("crypto_live", of: app)
    }

    /// One scroll-depth step down from `crypto_live`: a single real `swipeUp()`, verified
    /// against the header's own "Price To Beat" caption rather than trusted blind.
    ///
    /// The first attempt at this shot used `scrollTo` against the order book's heading —
    /// which turned out to already be on-screen (hittable with zero swipes) in every run,
    /// because on this device the whole live screen (header + chart + collapsed order book)
    /// fits, or nearly fits, in one viewport. `scrollTo` reporting "success" then proved
    /// nothing about the shot actually being scrolled — `crypto_live` and this shot came out
    /// visually identical modulo whatever the live ticker happened to show at the moment.
    /// So this instead performs the swipe unconditionally and *asserts the anchor actually
    /// moved* — proof the scroll had a real effect — rather than asserting an element merely
    /// became hittable, which this screen's own layout had already falsified as a proxy for
    /// "scrolled".
    func test_cryptoLiveSections() {
        let app = cryptoHub()
        openFirstMarket(in: app)
        let anchor = priceToBeatCaption(in: app)
        XCTAssertTrue(anchor.waitForExistence(timeout: UIWait.load), "No 'Price To Beat' header caption")
        let before = anchor.frame.minY
        app.swipeUp()
        settle(app)
        let after = anchor.exists ? anchor.frame.minY : before - 1
        XCTAssertNotEqual(before, after, accuracy: 1,
                          "Precondition: the live screen must actually scroll on a swipe")
        capture("crypto_live_sections", of: app)
    }

    /// A second scroll-depth step further than `crypto_live_sections`: two real `swipeUp()`
    /// calls from the top, again verified against the header caption rather than trusted
    /// blind. On this device the live screen's content (header + chart + collapsed order
    /// book + recent trades) is short enough that the *first* swipe alone can already reach
    /// the scroll view's bottom — so a second swipe on top of it may or may not move the
    /// content further depending on exactly how much the ladder/ticker are showing at the
    /// moment. Either way this asserts the *cumulative* two-swipe movement from the original
    /// top position is real, which is the one thing guaranteed regardless of how much of it
    /// the second swipe alone contributed.
    func test_cryptoDetailSections() {
        let app = cryptoHub()
        openFirstMarket(in: app)
        let anchor = priceToBeatCaption(in: app)
        XCTAssertTrue(anchor.waitForExistence(timeout: UIWait.load), "No 'Price To Beat' header caption")
        let before = anchor.frame.minY
        app.swipeUp()
        app.swipeUp()
        settle(app)
        let after = anchor.exists ? anchor.frame.minY : before - 1
        XCTAssertNotEqual(before, after, accuracy: 1,
                          "Precondition: the live screen must actually scroll on a swipe")
        capture("crypto_detail_sections", of: app)
    }

    /// Distinct from both `crypto_live_sections` and `crypto_detail_sections` (which capture
    /// the collapsed, 3-level book at two swipe depths): this one scrolls to the order
    /// book's own "Show more" control and taps it to expand the ladder to 10 levels per side
    /// (`OrderbookViewModel.expanded`) before capturing, so it renders a visibly larger,
    /// denser order book rather than reproducing one of the other two shots' scroll depths
    /// under a third name. `scrollTo`'s guarantee here is exactly what it claims — the
    /// button is what's being scrolled *to*, not incidentally already on-screen the way the
    /// order book heading turned out to be for the two shots above — so trusting its
    /// guarded result before tapping is safe.
    func test_orderbookLive() {
        let app = cryptoHub()
        openFirstMarket(in: app)
        let showMore = app.buttons["Show more"]
        XCTAssertTrue(app.scrollTo(showMore, maxSwipes: 14),
                      "Order book 'Show more' control never scrolled into view")
        showMore.tap()
        settle(app)
        capture("orderbook_live", of: app)
    }
}

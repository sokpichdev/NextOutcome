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

    /// Minimum vertical movement (in points) that counts as a real scroll rather than
    /// rubber-band jitter. Measured directly against this screen/device with a throwaway
    /// diagnostic test (`priceToBeatCaption`'s `frame.minY` before/after each gesture,
    /// three independent fresh-navigation runs — open the market, gesture, `goBack()`,
    /// repeat — each reproducing the same values to sub-point precision): unscrolled top ≈
    /// 192pt, a slow-velocity swipe (`swipeUp(velocity: 100)`) settles ≈ 3pt, a default
    /// `swipeUp()` settles ≈ -64pt. So the two real gestures this file performs move the
    /// anchor by ~189pt and ~257pt respectively — 100pt sits comfortably below both and far
    /// above anything a rubber-band bounce (observed at a few points at most) could produce.
    private static let minimumRealScroll: CGFloat = 100

    /// The boundary (in points) separating `crypto_live_sections`' verified shallower stop
    /// (~3pt, from `swipeUp(velocity: 100)`) from `crypto_detail_sections`' verified deeper
    /// stop (~-64pt, from a default `swipeUp()`) — see `minimumRealScroll`'s measurements.
    /// ~23pt of margin sits on each side, so ordinary run-to-run jitter can't cross it.
    private static let sectionsDepthBoundary: CGFloat = -20

    /// Reads `anchor`'s current vertical position, failing the test outright — never
    /// substituting a manufactured value — if the anchor has left the accessibility tree.
    /// A prior version of this file did `anchor.exists ? anchor.frame.minY : before - 1`:
    /// that fallback makes the caller's "did it move" assertion pass unconditionally no
    /// matter what actually happened on screen (navigation blown away, the anchor gone for
    /// a real reason) — a guard against silent failure that itself fails silently.
    private func requirePosition(of anchor: XCUIElement,
                                 file: StaticString = #filePath, line: UInt = #line) -> CGFloat? {
        guard anchor.exists else {
            XCTFail("Anchor disappeared after scrolling — cannot verify scroll depth", file: file, line: line)
            return nil
        }
        return anchor.frame.minY
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

    /// One scroll-depth step down from `crypto_live`: a slow-velocity swipe
    /// (`swipeUp(velocity: 100)`), verified by real, *bounded* movement of the header's
    /// "Price To Beat" caption — never trusted blind.
    ///
    /// The first attempt at this shot used `scrollTo` against the order book's heading,
    /// which was already on-screen with zero swipes (this screen's content fits, or nearly
    /// fits, in one viewport) — `scrollTo` reporting "success" proved nothing about actual
    /// scrolling. The second attempt used a plain `swipeUp()` guarded only by
    /// `XCTAssertNotEqual(before, after, accuracy: 1)` — too weak a bound: that only proves
    /// movement of more than 1pt, so a couple of points of rubber-band jitter would satisfy
    /// it while still producing a near-duplicate image, a green test hiding a regression.
    ///
    /// A throwaway diagnostic (see `minimumRealScroll`'s doc) found that a *default*
    /// `swipeUp()` always overshoots straight to the scroll view's bottom in one gesture —
    /// this screen's entire scrollable range is only ~257pt, far short of a default swipe's
    /// drag distance — so a default `swipeUp()` here lands at the same depth
    /// `crypto_detail_sections` uses, not an intermediate one. A slower, explicit gesture
    /// velocity, reproduced identically across three independent runs, reliably settles at
    /// a genuine intermediate stop instead, which `sectionsDepthBoundary` then verifies is
    /// strictly shallower than `crypto_detail_sections`' stop.
    func test_cryptoLiveSections() {
        let app = cryptoHub()
        openFirstMarket(in: app)
        let anchor = priceToBeatCaption(in: app)
        XCTAssertTrue(anchor.waitForExistence(timeout: UIWait.load), "No 'Price To Beat' header caption")
        let before = anchor.frame.minY
        app.windows.firstMatch.swipeUp(velocity: 100)
        settle(app)
        guard let after = requirePosition(of: anchor) else { return }
        XCTAssertGreaterThan(abs(before - after), Self.minimumRealScroll,
                             "The live screen must scroll by a real amount, not rubber-band jitter")
        XCTAssertGreaterThan(after, Self.sectionsDepthBoundary,
                             "This shot must stop short of crypto_detail_sections' deeper, fully-bottomed-out position — otherwise the two shots would be near-duplicates")
        capture("crypto_live_sections", of: app)
    }

    /// A second scroll-depth step further than `crypto_live_sections`: a single default
    /// `swipeUp()`, which the diagnostic behind `minimumRealScroll` confirmed reliably
    /// reaches the scroll view's true bottom on this screen in one gesture (its whole
    /// content is short enough that a default swipe overshoots straight to the end — see
    /// `test_cryptoLiveSections`'s comment). A prior version did two `swipeUp()` calls,
    /// following the original brief's "two swipes down" — the diagnostic showed the second
    /// swipe is a pure no-op here (identical anchor position before and after it, measured
    /// three times), so it added nothing but test time; dropped in favor of one swipe that's
    /// known to reach the bottom, plus an assertion that it actually did.
    ///
    /// Verified against the same header caption, with two guards: a real minimum movement
    /// (`minimumRealScroll`), and a position strictly deeper than `crypto_live_sections`'
    /// boundary (`sectionsDepthBoundary`) — so a run where both shots happened to settle at
    /// the same offset fails loudly here instead of silently shipping two near-duplicate
    /// README images under different names.
    func test_cryptoDetailSections() {
        let app = cryptoHub()
        openFirstMarket(in: app)
        let anchor = priceToBeatCaption(in: app)
        XCTAssertTrue(anchor.waitForExistence(timeout: UIWait.load), "No 'Price To Beat' header caption")
        let before = anchor.frame.minY
        app.swipeUp()
        settle(app)
        guard let after = requirePosition(of: anchor) else { return }
        XCTAssertGreaterThan(abs(before - after), Self.minimumRealScroll,
                             "The live screen must scroll by a real amount, not rubber-band jitter")
        XCTAssertLessThan(after, Self.sectionsDepthBoundary,
                          "This shot must reach deeper than crypto_live_sections' shallower stop — otherwise the two shots would be near-duplicates")
        capture("crypto_detail_sections", of: app)
    }

    /// Distinct from both `crypto_live_sections` and `crypto_detail_sections` (which capture
    /// the collapsed, 3-level book at two verified-different scroll depths): this one
    /// scrolls to the order book's own "Show more" control and taps it to expand the ladder
    /// to 10 levels per side (`OrderbookViewModel.expanded`) before capturing, so it renders
    /// a visibly larger, denser order book rather than reproducing one of the other two
    /// shots' scroll depths under a third name. `scrollTo`'s guarantee here is exactly what
    /// it claims — the button is what's being scrolled *to*, not incidentally already
    /// on-screen the way the order book heading turned out to be for the two shots above —
    /// so trusting its guarded result before tapping is safe.
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

//
//  TradingShots.swift
//  NextOutcomeUITests
//
//  Market detail (EventDetailView, reached the same way SportsShots/CryptoShots/EsportsShots
//  reach their detail screens — tapping an event's "Vol" caption from the trending feed) and
//  the mock trade flow it opens.
//
//  Launches with `-simulateGeoblock allowed` so the trade sheet opens no matter where the
//  machine running this is; the argument is handled in TradingAccessViewModel.
//
//  Submission is confirmed simulated by reading the source before writing any of this:
//  `TradeSheetViewModel.confirm()` (TradeSheetViewModel.swift) calls the `TradeSubmitting`
//  injected from the environment, and `SimulatedTradeSubmitter` (TradingDomain) is the only
//  conformer in the app — its own doc comment says it plainly: "Sends no order and persists
//  nothing. Waits ~300ms … then returns a simulated receipt." `TradeReceipt.simulated` is
//  hardcoded `true` there, and `TradeSheet`'s success screen shows that fact back to the user
//  as `successCaption`: "Simulated — trading arrives with funding". So `trade_confirm_alert`
//  and `trade_receipt` below submit no real order and move no money — confirmed from the
//  source, not assumed.
//
//  There is, however, no native confirmation alert anywhere in this flow — confirmed by
//  reading TradeSheet.swift and TradeSheetViewModel.swift end to end and grepping the Market
//  and Trading packages for `.alert(`, `UIAlertController`, and `confirmationDialog`: none
//  exist. `TradeSheetViewModel.Phase` has exactly three cases — `.entering` (trade_sheet),
//  `.submitting` (a ~300ms spinner-on-the-confirm-button state, driven by
//  `SimulatedTradeSubmitter`'s fixed delay), and `.success` (trade_receipt) — so
//  `trade_confirm_alert` captures that middle `.submitting` phase, the only state that sits
//  between the other two. See `test_tradeConfirmAlert` for how that narrow window is caught.
//

import XCTest

final class TradingShots: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Opens the first trending event, with trading permitted, landing on `EventDetailView`.
    ///
    /// Same technique as `SportsShots`/`CryptoShots`/`EsportsShots`: tap the "Vol" caption
    /// (`anyVolumeLabel`) rather than the brief's `buttons CONTAINS "Vol"`, which doesn't
    /// match anything here — `HomeCard`'s volume caption is a plain `staticText`, not part of
    /// a button label. Asserts the push actually happened (a back button appearing) rather
    /// than trusting the tap, per `MarketDetailUITests`' proven pattern for this exact
    /// transition.
    private func marketDetail() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-screenshotMode", "-simulateGeoblock", "allowed"]
        app.launch()
        settle(app, timeout: UIWait.firstLoad)
        XCTAssertTrue(app.anyVolumeLabel.waitForHittable(timeout: UIWait.load), "No market card to open")
        app.anyVolumeLabel.tap()
        XCTAssertTrue(app.backButton.waitForExistence(timeout: UIWait.load),
                      "Tapping a trending card never pushed a detail screen")
        settle(app, timeout: UIWait.ui)
        return app
    }

    /// The trade sheet's confirm button. Its label always carries the outcome name ("Trade
    /// Yes", "Trade No", or a team name for non-binary markets) — see
    /// `TradeSheet.confirmButton` and `TradeGateUITests.confirmButton`, which already proves
    /// this exact predicate against this exact app. The brief's "Confirm" text does not exist
    /// anywhere in `TradeSheet.swift`.
    ///
    /// Excludes an exact "Trade" match so this can never accidentally pick up
    /// `StickyEventHeader`'s own bare "Trade" shortcut button on the screen underneath the
    /// sheet, if that scrolled into its sticky state before the sheet was presented.
    private func confirmButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH[c] %@ AND label != %@", "Trade", "Trade")
        ).firstMatch
    }

    /// Finds, scrolls to, and taps the first "Buy" price button (`MarketGroupSection.row`
    /// composes it as "Buy Yes, 62¢" / "Buy <team>, 40¢" etc.), opening the trade sheet.
    ///
    /// The brief's `label BEGINSWITH "Yes"` predicate for a "sticky Yes button" describes
    /// `MarketDetailView`'s pinned bottom bar, a screen this flow never reaches (tapping an
    /// event's "Vol" caption pushes `EventDetailView`, not `MarketDetailView` — see
    /// `EventDetailDestination.swift`). `EventDetailView`'s own buy buttons are titled
    /// "Buy <outcome>", never bare "Yes"/"No", so `BEGINSWITH "Yes"` never matches here.
    ///
    /// A market group with no binary sub-market (e.g. a multi-candidate group with no
    /// Yes/No pair) renders no "Buy" button at all — `MarketGroupSection.row` only builds one
    /// `if let sides = market.binaryOutcomes`. `TradeGateUITests.launchAndOpenTradeSheet`
    /// treats the identical situation (no priced/binary market in the day's top result) as a
    /// live-data skip rather than a regression, and this follows that precedent.
    /// - Parameters:
    ///   - app: The application under test.
    ///   - name: The screenshot name, used in the skip message if no Buy button exists.
    private func tapBuyYes(in app: XCUIApplication, named name: String) throws {
        let buyYes = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH[c] %@", "Buy")).firstMatch
        guard app.scrollTo(buyYes, maxSwipes: 12) else {
            if buyYes.exists {
                XCTFail("'Buy' price button never scrolled into view")
            } else {
                throw XCTSkip("SKIPPED-SHOT \(name): no binary 'Buy' price button on today's top trending market")
            }
            return
        }
        buyYes.tap()
        settle(app, timeout: UIWait.ui)
        // Anchored on the trade sheet's own "To win" payout row (`TradeSheet.toWinRow`) —
        // content that exists nowhere else in this flow — rather than trusting the tap.
        XCTAssertTrue(app.staticTexts["To win"].waitForExistence(timeout: UIWait.ui),
                      "Tap did not open the trade sheet — its 'To win' payout row never appeared")
    }

    func test_marketDetail() {
        let app = marketDetail()
        // Guard against capturing market_detail_sticky_bar's state under this name: the
        // sticky header's "Trade" shortcut must not already be showing (it only appears
        // once the user scrolls past the hero chart — see EventDetailView.showsStickyHeader).
        XCTAssertFalse(app.buttons["Trade"].exists,
                       "market_detail must capture before the sticky header appears")
        capture("market_detail", of: app)
    }

    /// Distinguished from `market_detail` by the appearance of `EventDetailView`'s own
    /// `StickyEventHeader` (a bare "Trade" button, overlaid once the hero region — the
    /// header/chart — scrolls above the top edge; see `EventDetailView.showsStickyHeader`
    /// and `HeroScrollOffsetKey`). That's a stronger guard than a raw before/after scroll
    /// position: it directly proves the exact visual element this shot exists to capture,
    /// rather than merely proving *some* scrolling happened (the failure mode the crypto
    /// shots' `requirePosition` measurements were written to catch).
    func test_marketDetailStickyBar() {
        let app = marketDetail()
        let tradeShortcut = app.buttons["Trade"]
        var revealed = tradeShortcut.exists
        var attempts = 0
        while !revealed, attempts < 3 {
            app.swipeUp()
            settle(app, timeout: UIWait.ui)
            revealed = tradeShortcut.waitForExistence(timeout: UIWait.ui)
            attempts += 1
        }
        XCTAssertTrue(revealed, "Sticky header's 'Trade' shortcut never appeared after scrolling")
        capture("market_detail_sticky_bar", of: app)
    }

    func test_tradeSheet() throws {
        let app = marketDetail()
        try tapBuyYes(in: app, named: "trade_sheet")
        capture("trade_sheet", of: app)
    }

    /// Captures `TradeSheetViewModel.Phase.submitting` — the only state this app actually has
    /// between `trade_sheet` (`.entering`) and `trade_receipt` (`.success`); see this file's
    /// header comment for why there is no native alert to capture instead.
    ///
    /// `phase = .submitting` is set synchronously, before any `await`, at the very top of
    /// `confirm()` — so it takes effect the instant the button's action runs, well before
    /// `SimulatedTradeSubmitter`'s fixed ~300ms delay elapses. `XCUIElement.tap()` waits for
    /// the app to reach a quiescent/idle state before returning, which on this exact
    /// transition can mean waiting for the success screen's own `.easeOut` entrance animation
    /// to finish — i.e. past the window entirely. A coordinate tap sidesteps that
    /// element-hittability/quiescence wait (it's a raw synthesized touch at an
    /// already-resolved point), so the very next line — a screenshot, which itself needs no
    /// accessibility snapshot — reliably lands inside the ~300ms window instead of after it.
    ///
    /// Verified, not trusted: two assertions after capturing check what phase the app
    /// actually landed on, catching either failure mode this technique could still hit —
    /// the tap not registering at all (still `.entering`, a duplicate of `trade_sheet`) or
    /// the window being missed anyway (already `.success`, a duplicate of `trade_receipt`).
    func test_tradeConfirmAlert() throws {
        let app = marketDetail()
        try tapBuyYes(in: app, named: "trade_confirm_alert")

        let confirm = confirmButton(in: app)
        XCTAssertTrue(confirm.waitForHittable(timeout: UIWait.ui), "No confirm button")
        let orderPlaced = app.staticTexts["Order Placed!"]
        XCTAssertFalse(orderPlaced.exists, "Already on the receipt before confirming — flow desynced")

        confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        capture("trade_confirm_alert", of: app)

        XCTAssertFalse(confirmButton(in: app).exists,
                       "trade_confirm_alert: sheet still reads as entering an amount — captured a duplicate of trade_sheet")
        XCTAssertFalse(app.staticTexts["Order Placed!"].exists,
                       "trade_confirm_alert: already showing the receipt — missed the submitting window, captured a duplicate of trade_receipt")
    }

    func test_tradeReceipt() throws {
        let app = marketDetail()
        try tapBuyYes(in: app, named: "trade_receipt")

        let confirm = confirmButton(in: app)
        XCTAssertTrue(confirm.waitForHittable(timeout: UIWait.ui), "No confirm button")
        confirm.tap()

        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: UIWait.load), "Receipt never appeared")
        // Don't trust "Done" alone — assert the receipt's own success content is what's on
        // screen, not just that some button happens to say "Done".
        XCTAssertTrue(app.staticTexts["Order Placed!"].exists,
                      "trade_receipt: 'Done' button appeared without the receipt content")
        capture("trade_receipt", of: app)
    }

    /// `EventDetailView`'s toolbar "Discuss" action has no "Discuss" text anywhere — its
    /// button carries only an explicit `.accessibilityLabel("Comments and activity")` over a
    /// bare `bubble.left` glyph (see `DetailToolbar.trailingActions`), so the brief's
    /// `CONTAINS "Discuss"` predicate never matches. Matched by substring on the real label
    /// instead, and landing verified via the sheet's own "Top Holders" tab chip
    /// (`SocialTab.holders.title`, `ChipRow`) — plain, uncomposed text unique to this sheet.
    func test_discussSheet() {
        let app = marketDetail()
        let discuss = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Comments")).firstMatch
        XCTAssertTrue(discuss.waitForHittable(timeout: UIWait.ui), "No comments/discuss toolbar button")
        discuss.tap()
        settle(app, timeout: UIWait.ui)
        let topHolders = app.buttons["Top Holders"]
        XCTAssertTrue(topHolders.waitForExistence(timeout: UIWait.ui),
                      "Tap did not open the Discuss sheet — its 'Top Holders' tab never appeared")
        capture("discuss_sheet", of: app)
    }
}

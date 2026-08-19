//
//  TradeSheetViewModelTests.swift
//  NextOutcome
//

import XCTest
@testable import MarketsPresentation
import MarketsDomain
import TradingDomain

private struct StubTradeSubmitter: TradeSubmitting {
    func submit(marketID: String, side: TradingDomain.TradeSide, amountUSD: Decimal, priceCents: Decimal) async throws -> TradeReceipt {
        TradeReceipt(simulated: true, shares: 0)
    }
}

@MainActor
final class TradeSheetViewModelTests: XCTestCase {
    private func makeMarket() -> Market {
        Market(
            id: "m1",
            question: "Will it happen?",
            slug: "will-it-happen",
            outcomes: [
                Outcome(id: "y", title: "Yes", price: 0.5),
                Outcome(id: "n", title: "No", price: 0.5)
            ],
            volume: 0,
            liquidity: 0,
            endDate: nil,
            isResolved: false,
            imageURL: nil
        )
    }

    private func makeVM() -> TradeSheetViewModel {
        TradeSheetViewModel(market: makeMarket(), side: .yes, submitter: StubTradeSubmitter())
    }

    /// The crypto live screen's $5/$25/$100 tiles are what place the bet, so the sheet
    /// they open must already hold that stake — the user only confirms.
    func test_initialDollars_prefillsTheAmount() {
        let vm = TradeSheetViewModel(
            market: makeMarket(), side: .yes, submitter: StubTradeSubmitter(), initialDollars: 25
        )

        XCTAssertEqual(vm.amountDisplay, "$25.00")
        XCTAssertEqual(vm.amountUSD, 25)
    }

    /// A pre-filled amount is still editable: backspace removes digits from it.
    func test_prefilledAmount_staysEditable() {
        let vm = TradeSheetViewModel(
            market: makeMarket(), side: .yes, submitter: StubTradeSubmitter(), initialDollars: 50
        )

        vm.backspace()

        XCTAssertEqual(vm.amountDisplay, "$5.00")
        XCTAssertEqual(vm.amountUSD, 5)
    }

    /// Inputting "1" produces $1.00 (whole dollars first, not $0.01).
    func test_appendDigit_inputsWholeDollarsFirst() {
        let vm = makeVM()

        XCTAssertEqual(vm.amountDisplay, "$0.00")

        vm.appendDigit(1)
        XCTAssertEqual(vm.amountDisplay, "$1.00")
        XCTAssertEqual(vm.amountUSD, 1)
        XCTAssertEqual(vm.amountCents, 100)

        vm.appendDigit(5)
        XCTAssertEqual(vm.amountDisplay, "$15.00")
        XCTAssertEqual(vm.amountUSD, 15)
        XCTAssertEqual(vm.amountCents, 1500)
    }

    /// Tapping "." transitions to cent entry.
    func test_appendDecimal_allowsCentsInput() {
        let vm = makeVM()

        vm.appendDigit(1)
        vm.appendDecimal()
        XCTAssertEqual(vm.amountDisplay, "$1.")

        vm.appendDigit(5)
        XCTAssertEqual(vm.amountDisplay, "$1.50")
        XCTAssertEqual(vm.amountUSD, Decimal(string: "1.50"))
        XCTAssertEqual(vm.amountCents, 150)

        vm.appendDigit(2)
        XCTAssertEqual(vm.amountDisplay, "$1.52")
        XCTAssertEqual(vm.amountUSD, Decimal(string: "1.52"))
        XCTAssertEqual(vm.amountCents, 152)

        // Additional digits beyond 2 decimal places are ignored.
        vm.appendDigit(9)
        XCTAssertEqual(vm.amountDisplay, "$1.52")
        XCTAssertEqual(vm.amountCents, 152)
    }

    /// Tapping "." on an empty pad starts "$0.".
    func test_appendDecimal_onEmptyPad_startsZeroDecimal() {
        let vm = makeVM()

        vm.appendDecimal()
        XCTAssertEqual(vm.amountDisplay, "$0.")

        vm.appendDigit(5)
        XCTAssertEqual(vm.amountDisplay, "$0.50")
        XCTAssertEqual(vm.amountUSD, Decimal(string: "0.50"))
        XCTAssertEqual(vm.amountCents, 50)

        // Duplicate "." is ignored
        vm.appendDecimal()
        XCTAssertEqual(vm.amountDisplay, "$0.50")
    }

    /// Backspacing removes decimals and digits sequentially.
    func test_backspace_removesDecimalsAndDigitsSequentially() {
        let vm = makeVM()

        vm.appendDigit(1)
        vm.appendDecimal()
        vm.appendDigit(5)
        vm.appendDigit(2)
        XCTAssertEqual(vm.amountDisplay, "$1.52")

        vm.backspace()
        XCTAssertEqual(vm.amountDisplay, "$1.50")
        XCTAssertEqual(vm.amountCents, 150)

        vm.backspace()
        XCTAssertEqual(vm.amountDisplay, "$1.")
        XCTAssertEqual(vm.amountCents, 100)

        vm.backspace()
        XCTAssertEqual(vm.amountDisplay, "$1.00")
        XCTAssertEqual(vm.amountCents, 100)

        vm.backspace()
        XCTAssertEqual(vm.amountDisplay, "$0.00")
        XCTAssertEqual(vm.amountCents, 0)
    }

    func test_addAmount_accumulatesWholeDollars() {
        let vm = makeVM()

        vm.addAmount(1)
        vm.addAmount(10)
        vm.addAmount(100)

        XCTAssertEqual(vm.amountCents, 111_00)
        XCTAssertEqual(vm.amountDisplay, "$111.00")
    }

    func test_addAmount_respectsCeiling() {
        let vm = makeVM()

        // 100_000_00 cents = $100,000 ceiling. Two +$100k adds: the first lands exactly
        // on the ceiling, the second must be rejected.
        vm.addAmount(100_000)
        XCTAssertEqual(vm.amountCents, 100_000_00)
        vm.addAmount(100_000)
        XCTAssertEqual(vm.amountCents, 100_000_00, "add that overflows the ceiling must be rejected")
    }

    func test_setSide_switchesOutcomeAndPrice() {
        let vm = makeVM()

        XCTAssertEqual(vm.side, .yes)
        vm.setSide(.no)

        XCTAssertEqual(vm.side, .no)
        XCTAssertEqual(vm.outcomeTitle, "No")
        XCTAssertEqual(vm.priceCents, 50) // No price 0.5 * 100
    }

    func test_clear_resetsAmount() {
        let vm = makeVM()

        vm.addAmount(100)
        vm.clear()

        XCTAssertEqual(vm.amountCents, 0)
        XCTAssertEqual(vm.amountDisplay, "$0.00")
    }
}

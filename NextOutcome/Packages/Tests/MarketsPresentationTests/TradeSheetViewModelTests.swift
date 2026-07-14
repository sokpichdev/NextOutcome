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

    func test_amountDisplay_showsCents() {
        let vm = makeVM()

        XCTAssertEqual(vm.amountDisplay, "$0.00")

        vm.appendDigit(1)
        vm.appendDigit(5)
        vm.appendDigit(0)

        XCTAssertEqual(vm.amountDisplay, "$1.50")
        XCTAssertEqual(vm.amountUSD, Decimal(string: "1.50"))
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

    func test_appendDoubleZero_appendsBothZeroes() {
        let vm = makeVM()

        vm.appendDigit(5)
        vm.appendDoubleZero()

        XCTAssertEqual(vm.amountCents, 500)
        XCTAssertEqual(vm.amountDisplay, "$5.00")
    }

    func test_appendDoubleZero_respectsCeiling_asAUnit() {
        let vm = makeVM()

        // 500_000 * 100 overflows the 100_000_00 ceiling. The "00" key must be rejected
        // whole — taking only the first zero would leave an amount the user never typed.
        for digit in [5, 0, 0, 0, 0, 0] {
            vm.appendDigit(digit)
        }
        XCTAssertEqual(vm.amountCents, 500_000)

        vm.appendDoubleZero()
        XCTAssertEqual(vm.amountCents, 500_000, "\"00\" that overflows the ceiling must be rejected whole")
    }

    func test_clear_resetsAmount() {
        let vm = makeVM()

        vm.addAmount(100)
        vm.clear()

        XCTAssertEqual(vm.amountCents, 0)
        XCTAssertEqual(vm.amountDisplay, "$0.00")
    }

    func test_appendDigit_overflowGuard_usesRealFormula() {
        let vm = makeVM()

        // Drive amountCents to 9_999_999 (just below the 100_000_00 ceiling) using the
        // real update formula (amountCents * 10 + digit), then confirm the guard blocks
        // any digit that would push it over 100_000_00 but allows one that keeps it under.
        for digit in [9, 9, 9, 9, 9, 9, 9] {
            vm.appendDigit(digit)
        }
        XCTAssertEqual(vm.amountCents, 9_999_999)

        // 9_999_999 * 10 + 9 = 99_999_999, still <= 100_000_00? No: 100_000_00 = 10_000_000.
        // 99_999_999 > 10_000_000, so this digit must be rejected.
        vm.appendDigit(9)
        XCTAssertEqual(vm.amountCents, 9_999_999, "digit that overflows the ceiling must be rejected")
    }
}

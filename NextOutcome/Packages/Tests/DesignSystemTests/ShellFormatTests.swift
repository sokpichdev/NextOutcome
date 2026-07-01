import XCTest
@testable import DesignSystem

final class ShellFormatTests: XCTestCase {
    func test_balanceLabel_formatsTwoDecimalsWithDollar() {
        XCTAssertEqual(ShellFormat.balanceLabel(Decimal(string: "7.02")), "$\u{A0}7.02")
    }

    func test_balanceLabel_wholeNumber_stillTwoDecimals() {
        XCTAssertEqual(ShellFormat.balanceLabel(Decimal(7)), "$\u{A0}7.00")
    }

    func test_balanceLabel_nilIsPlaceholder() {
        XCTAssertEqual(ShellFormat.balanceLabel(nil), "$--")
    }

    func test_shortAddress_truncatesTo0xPlusEightThenEllipsis() {
        XCTAssertEqual(
            ShellFormat.shortAddress("0xd8C7e8F26546f64e1234567890"),
            "0xd8C7e8F2…"
        )
    }

    func test_shortAddress_nilIsEmptyDash() {
        XCTAssertEqual(ShellFormat.shortAddress(nil), "—")
    }
}

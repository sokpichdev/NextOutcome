//
//  BTCLiveHeaderFormattingTests.swift
//  NextOutcome
//

import XCTest
@testable import OrderbookPresentation
import Foundation

/// The pure formatting behind the live screen's web-style header: the split countdown
/// blocks and the window's time range. All static, so none of these need a view model.
final class BTCLiveHeaderFormattingTests: XCTestCase {

    // MARK: Countdown units

    func test_countdownUnits_underAnHour_splitsIntoMinutesAndSeconds() {
        XCTAssertEqual(
            BTCLiveViewModel.countdownUnits(remainingSeconds: 90),
            [CountdownUnit(value: "01", label: "MIN"), CountdownUnit(value: "30", label: "SECS")]
        )
    }

    func test_countdownUnits_padsSingleDigitsToTwo() {
        XCTAssertEqual(
            BTCLiveViewModel.countdownUnits(remainingSeconds: 9),
            [CountdownUnit(value: "00", label: "MIN"), CountdownUnit(value: "09", label: "SECS")]
        )
    }

    func test_countdownUnits_atZero_readsZeroZero() {
        XCTAssertEqual(
            BTCLiveViewModel.countdownUnits(remainingSeconds: 0),
            [CountdownUnit(value: "00", label: "MIN"), CountdownUnit(value: "00", label: "SECS")]
        )
    }

    /// A daily window has hours left, and "1320 MIN" is not a countdown — over an hour the
    /// two most significant units become hours and minutes.
    func test_countdownUnits_overAnHour_splitsIntoHoursAndMinutes() {
        XCTAssertEqual(
            BTCLiveViewModel.countdownUnits(remainingSeconds: 5_400),
            [CountdownUnit(value: "01", label: "HRS"), CountdownUnit(value: "30", label: "MIN")]
        )
    }

    func test_countdownUnits_justUnderADay_staysInHoursAndMinutes() {
        XCTAssertEqual(
            BTCLiveViewModel.countdownUnits(remainingSeconds: 86_399),
            [CountdownUnit(value: "23", label: "HRS"), CountdownUnit(value: "59", label: "MIN")]
        )
    }

    /// The boundary itself: exactly one hour is still hours-and-minutes, one second less
    /// has already dropped to minutes-and-seconds.
    func test_countdownUnits_atTheHourBoundary_switchesUnits() {
        XCTAssertEqual(
            BTCLiveViewModel.countdownUnits(remainingSeconds: 3_600).map(\.label),
            ["HRS", "MIN"]
        )
        XCTAssertEqual(
            BTCLiveViewModel.countdownUnits(remainingSeconds: 3_599).map(\.label),
            ["MIN", "SECS"]
        )
    }

    // MARK: Window range

    /// The New York zone the fixtures below are read in, matching how a user in ET would
    /// see the same window the web labels "8:25-8:30AM ET".
    private let eastern = TimeZone(identifier: "America/New_York")!

    /// 2026-08-18 08:25 ET.
    private var windowOpen: Date {
        DateComponents(
            calendar: Calendar(identifier: .gregorian), timeZone: eastern,
            year: 2026, month: 8, day: 18, hour: 8, minute: 25
        ).date!
    }

    func test_windowRange_withinOneMeridiem_printsItOnce() {
        let range = BTCLiveViewModel.windowRange(
            start: windowOpen,
            end: windowOpen.addingTimeInterval(300),
            timeZone: eastern
        )
        XCTAssertEqual(range, "Aug 18, 8:25–8:30 AM")
    }

    func test_windowRange_crossingNoon_printsBothMeridiems() {
        let start = windowOpen.addingTimeInterval(3.5 * 3_600)  // 11:55 AM
        let range = BTCLiveViewModel.windowRange(
            start: start,
            end: start.addingTimeInterval(300),                 // 12:00 PM
            timeZone: eastern
        )
        XCTAssertEqual(range, "Aug 18, 11:55 AM–12:00 PM")
    }

    /// A daily window spans two calendar days, so the end needs its own date.
    func test_windowRange_crossingMidnight_datesBothEnds() {
        let start = windowOpen.addingTimeInterval(12 * 3_600)   // Aug 18, 8:25 PM
        let range = BTCLiveViewModel.windowRange(
            start: start,
            end: start.addingTimeInterval(24 * 3_600),          // Aug 19, 8:25 PM
            timeZone: eastern
        )
        XCTAssertEqual(range, "Aug 18, 8:25 PM–Aug 19, 8:25 PM")
    }

    // MARK: Potential win

    /// The web's own numbers: $5 on a 24¢ side wins $21, $25 wins $104, $100 wins $417
    /// (all before the view rounds them to whole dollars).
    func test_potentialWin_matchesSharesTimesOneDollar() {
        XCTAssertEqual(BTCLiveViewModel.potentialWin(dollars: 5, cents: 24), 20.83)
        XCTAssertEqual(BTCLiveViewModel.potentialWin(dollars: 25, cents: 24), 104.17)
        XCTAssertEqual(BTCLiveViewModel.potentialWin(dollars: 100, cents: 24), 416.67)
    }

    func test_potentialWin_atZeroCents_isZeroRatherThanInfinite() {
        XCTAssertEqual(BTCLiveViewModel.potentialWin(dollars: 25, cents: 0), 0)
    }
}

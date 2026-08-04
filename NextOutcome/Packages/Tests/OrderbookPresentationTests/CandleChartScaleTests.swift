//
//  CandleChartScaleTests.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/08/2026.
//

import XCTest
@testable import OrderbookPresentation

/// The candle chart's y-band. The property under test is *stillness*: a live tick that
/// stays inside the band must not move it, because moving it rescales every candle and —
/// via the y-axis label width — shifts them sideways too.
final class CandleChartScaleTests: XCTestCase {
    /// The regression test for the reported bug: candles shimmying on every RTDS tick.
    func test_bandDoesNotMoveWhileTicksStayInside() {
        var scale = CandleChartScale()
        XCTAssertTrue(scale.absorb(low: 63_800, high: 63_900))
        let settled = scale.domain

        // 200 ticks jittering inside the band. `low` holds because it comes from the
        // seeded history; only the forming candle's high moves, which is exactly the
        // shape of a live window.
        for step in 0..<200 {
            let high = 63_895 + Double(step % 11)
            XCTAssertFalse(
                scale.absorb(low: 63_800, high: high),
                "a tick inside the band must not re-publish the domain"
            )
        }
        XCTAssertEqual(scale.domain, settled)
    }

    func test_bandGrowsWhenThePriceLeavesIt() {
        var scale = CandleChartScale()
        scale.absorb(low: 63_800, high: 63_900)
        let escaped = scale.domain!.upperBound + 50

        XCTAssertTrue(scale.absorb(low: 63_800, high: escaped))
        XCTAssertGreaterThanOrEqual(scale.domain!.upperBound, escaped)
        XCTAssertLessThanOrEqual(scale.domain!.lowerBound, 63_800)
    }

    /// The hysteresis property: a series sitting exactly on a quantisation boundary must
    /// not flap between two bands as the price crosses it back and forth.
    func test_bandDoesNotFlapAcrossAQuantisationBoundary() {
        var scale = CandleChartScale()
        scale.absorb(low: 63_800, high: 63_999.9)

        var changes = 0
        for step in 0..<20 {
            if scale.absorb(low: 63_800, high: step.isMultiple(of: 2) ? 64_000.1 : 63_999.9) {
                changes += 1
            }
        }
        XCTAssertLessThanOrEqual(changes, 1, "the band flapped \(changes) times across the boundary")
    }

    func test_bandTightensOnlyWhenTheDataShrinksWellInside() {
        var scale = CandleChartScale()
        scale.absorb(low: 63_000, high: 64_000)
        let wide = scale.domain!
        let span = wide.upperBound - wide.lowerBound
        let mid = (wide.lowerBound + wide.upperBound) / 2

        // Still filling ~90% of the band: leave it alone.
        XCTAssertFalse(scale.absorb(low: mid - span * 0.45, high: mid + span * 0.45))
        XCTAssertEqual(scale.domain, wide)

        // Collapsed to ~20%: worth re-fitting.
        XCTAssertTrue(scale.absorb(low: mid - span * 0.1, high: mid + span * 0.1))
        let tight = scale.domain!
        XCTAssertLessThan(tight.upperBound - tight.lowerBound, span)
    }

    func test_boundsLandOnNiceSteps() {
        let domain = CandleChartScale.quantised(low: 63_812.37, high: 63_941.06)
        let step = CandleChartScale.step(low: 63_812.37, high: 63_941.06)
        XCTAssertEqual((domain.lowerBound / step).rounded(), domain.lowerBound / step, accuracy: 1e-6)
        XCTAssertEqual((domain.upperBound / step).rounded(), domain.upperBound / step, accuracy: 1e-6)
        XCTAssertLessThanOrEqual(domain.lowerBound, 63_812.37)
        XCTAssertGreaterThanOrEqual(domain.upperBound, 63_941.06)
    }

    func test_niceStepLadder() {
        XCTAssertEqual(CandleChartScale.niceStep(0.9), 1, accuracy: 1e-9)
        XCTAssertEqual(CandleChartScale.niceStep(1.7), 2, accuracy: 1e-9)
        XCTAssertEqual(CandleChartScale.niceStep(2.3), 2.5, accuracy: 1e-9)
        XCTAssertEqual(CandleChartScale.niceStep(4), 5, accuracy: 1e-9)
        XCTAssertEqual(CandleChartScale.niceStep(9), 10, accuracy: 1e-9)
        XCTAssertEqual(CandleChartScale.niceStep(180), 200, accuracy: 1e-9)
    }

    /// Degenerate inputs must fall back rather than produce a NaN step and a crashing range.
    func test_niceStepSurvivesDegenerateInput() {
        XCTAssertEqual(CandleChartScale.niceStep(0), 1)
        XCTAssertEqual(CandleChartScale.niceStep(-5), 1)
        XCTAssertEqual(CandleChartScale.niceStep(.nan), 1)
        XCTAssertEqual(CandleChartScale.niceStep(.infinity), 1)
    }

    func test_flatSeriesStillGetsANonEmptyBand() {
        let domain = CandleChartScale.quantised(low: 63_800, high: 63_800)
        XCTAssertGreaterThan(domain.upperBound, domain.lowerBound)
        XCTAssertTrue(domain.contains(63_800))
    }

    /// A non-finite extreme (a mis-mapped price) must be ignored, not poison the band.
    func test_nonFiniteExtremesAreIgnored() {
        var scale = CandleChartScale()
        scale.absorb(low: 63_800, high: 63_900)
        let settled = scale.domain

        XCTAssertFalse(scale.absorb(low: .nan, high: 63_900))
        XCTAssertFalse(scale.absorb(low: 63_800, high: .infinity))
        XCTAssertEqual(scale.domain, settled)
    }
}

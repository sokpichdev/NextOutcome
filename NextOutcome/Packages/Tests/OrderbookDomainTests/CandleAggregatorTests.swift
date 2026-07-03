//
//  CandleAggregatorTests.swift
//  NextOutcome
//

import XCTest
import Foundation
@testable import OrderbookDomain

/// Test helper mirroring the brief's `.p(value, date)` fixture. `PricePoint` is the
/// domain price-sample type consumed by `CandleAggregator`.
extension PricePoint {
    static func p(_ price: Decimal, _ date: Date) -> PricePoint {
        PricePoint(date: date, price: price)
    }
}

final class CandleAggregatorTests: XCTestCase {
    func testOHLCPerBucket() {
        let t0 = Date(timeIntervalSince1970: 0)
        let pts: [PricePoint] = [.p(0.50, t0), .p(0.55, t0 + 10), .p(0.48, t0 + 20), .p(0.52, t0 + 30)]
        let c = CandleAggregator.candles(from: pts, interval: 60)[0]
        XCTAssertEqual([c.open, c.high, c.low, c.close], [0.50, 0.55, 0.48, 0.52])
    }

    func testGapBucketCarriesClose() {
        let t0 = Date(timeIntervalSince1970: 0)
        let cs = CandleAggregator.candles(from: [.p(0.5, t0), .p(0.6, t0 + 130)], interval: 60)
        XCTAssertEqual(cs.count, 3)
        XCTAssertEqual(cs[1].close, 0.5) // empty middle bucket carries prior close
        XCTAssertEqual(cs[1].open, 0.5)
        XCTAssertEqual(cs[1].high, 0.5)
        XCTAssertEqual(cs[1].low, 0.5)
    }

    /// Buckets align to interval boundaries measured from the epoch, regardless of the
    /// first sample's offset within its bucket.
    func testBucketAlignmentToIntervalBoundaries() {
        let p1 = PricePoint(date: Date(timeIntervalSince1970: 90), price: 0.40)
        let p2 = PricePoint(date: Date(timeIntervalSince1970: 110), price: 0.50)
        let cs = CandleAggregator.candles(from: [p1, p2], interval: 60)
        XCTAssertEqual(cs.count, 1)
        // 90 and 110 both fall in the [60, 120) bucket, which starts at t=60.
        XCTAssertEqual(cs[0].start, Date(timeIntervalSince1970: 60))
        XCTAssertEqual(cs[0].open, 0.40)
        XCTAssertEqual(cs[0].close, 0.50)
    }
}

//
//  PerfSignpostTests.swift
//  NextOutcome
//

import XCTest
@testable import SharedDomain

/// The signpost wrapper sits inside two hot paths (`HomeCardKind.classify` and the
/// `visibleEvents` pipelines), so the one thing that must never be in doubt is that it is
/// *transparent*: same value out, same errors thrown, no behaviour of its own.
///
/// Whether a signpost is actually emitted isn't testable in-process — that's Instruments'
/// job, and the emission path is a no-op unless a trace is recording. See
/// `docs/performance/baselines.md` for how the intervals are read.
final class PerfSignpostTests: XCTestCase {
    func testMeasureReturnsTheBodysValue() {
        let result = Perf.renderPath.measure(Perf.classifyCard) { 42 }
        XCTAssertEqual(result, 42)
    }

    func testMeasureRethrows() {
        struct Boom: Error {}
        XCTAssertThrowsError(
            try Perf.renderPath.measure(Perf.classifyCard) { throw Boom() }
        ) { error in
            XCTAssertTrue(error is Boom)
        }
    }

    func testMeasureRunsTheBodyExactlyOnce() {
        var calls = 0
        _ = Perf.renderPath.measure(Perf.visibleEventsHome) { calls += 1 }
        XCTAssertEqual(calls, 1)
    }
}

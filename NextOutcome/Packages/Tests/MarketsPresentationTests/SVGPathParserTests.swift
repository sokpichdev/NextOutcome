import XCTest
import SwiftUI
@testable import MarketsPresentation

final class SVGPathParserTests: XCTestCase {
    func test_absoluteMoveAndLine_tracesExpectedBounds() {
        let path = SVGPathParser.path(from: "M 0,0 L 10,0 L 10,10 L 0,10 Z")
        let bounds = path.boundingRect
        XCTAssertEqual(bounds, CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    func test_relativeMoveAndLine_accumulatesFromCurrentPoint() {
        let path = SVGPathParser.path(from: "m 5,5 l 10,0 l 0,10 l -10,0 z")
        let bounds = path.boundingRect
        XCTAssertEqual(bounds, CGRect(x: 5, y: 5, width: 10, height: 10))
    }

    func test_implicitRepeatedCoordinatePairs_areTreatedAsLineto() {
        // "l 10,0 5,5" == "l 10,0 l 5,5" — a bare coordinate pair after an l repeats it.
        let path = SVGPathParser.path(from: "M 0,0 l 10,0 5,5")
        let bounds = path.boundingRect
        XCTAssertEqual(bounds, CGRect(x: 0, y: 0, width: 15, height: 5))
    }

    func test_moveto_implicitFollowupPairs_areTreatedAsLineto() {
        // Per the SVG spec, extra coordinate pairs right after an initial M/m are linetos.
        let path = SVGPathParser.path(from: "M 0,0 10,0 10,10")
        let bounds = path.boundingRect
        XCTAssertEqual(bounds, CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    func test_horizontalAndVerticalLineto_absoluteAndRelative() {
        let path = SVGPathParser.path(from: "M 0,0 H 10 V 10 h -10 v -10")
        let bounds = path.boundingRect
        XCTAssertEqual(bounds, CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    func test_negativeNumberWithNoSeparator_parsesAsDistinctNumbers() {
        // Real source data glues negative numbers together with no comma, e.g. "3.4-1.2".
        let path = SVGPathParser.path(from: "M 0,0 l 3.4-1.2 1-1")
        // Two linetos: (+3.4,-1.2) then (+1,-1) → final point (4.4, -2.2).
        XCTAssertEqual(path.currentPoint?.x ?? 0, 4.4, accuracy: 0.001)
        XCTAssertEqual(path.currentPoint?.y ?? 0, -2.2, accuracy: 0.001)
    }

    func test_closepath_returnsToSubpathStart() {
        let path = SVGPathParser.path(from: "M 1,1 l 5,0 l 0,5 z l 2,2")
        // After z, current point resets to the subpath start (1,1) before the next lineto.
        XCTAssertEqual(path.currentPoint, CGPoint(x: 3, y: 3))
    }

    /// Regression test against real source data: Colorado's roughly-rectangular outline
    /// (verified against its known real-world aspect ratio, ~1.26).
    func test_realStatePath_colorado_producesExpectedBounds() {
        let d = "m 374.6,323.3 -16.5,-1 -51.7,-4.8 -52.6,-6.5 11.5,-88.3 44.9,5.7 37.5,3.4 33.1,2.4 -1.4,22.1 z"
        let bounds = SVGPathParser.path(from: d).boundingRect
        XCTAssertEqual(bounds.width, 127.0, accuracy: 0.5)
        XCTAssertEqual(bounds.height, 100.6, accuracy: 0.5)
    }

    func test_emptyString_producesEmptyPath() {
        XCTAssertTrue(SVGPathParser.path(from: "").isEmpty)
    }

    func test_everyEmbeddedStatePath_parsesWithoutCrashing_andYieldsNonEmptyBounds() {
        for (code, d) in USStateGeometry.paths {
            let bounds = SVGPathParser.path(from: d).boundingRect
            XCTAssertGreaterThan(bounds.width, 0, "\(code) produced an empty/degenerate path")
            XCTAssertGreaterThan(bounds.height, 0, "\(code) produced an empty/degenerate path")
        }
    }
}

//
//  WorldLandMaskTests.swift
//  NextOutcome
//

@testable import MarketsPresentation
import XCTest

final class WorldLandMaskTests: XCTestCase {
    func test_cells_coverTheWholeGrid() {
        XCTAssertEqual(WorldLandMask.cells.count, WorldLandMask.width * WorldLandMask.height)
    }

    func test_landCoverage_isRoughlyThirtyPercent() {
        let land = Double(WorldLandMask.cells.filter { $0 }.count)
        let fraction = land / Double(WorldLandMask.cells.count)
        // Land is ~29% of the Earth's surface, but an equirectangular grid over-weights the
        // poles, which inflates Antarctica and Greenland, so allow a generous band.
        XCTAssertGreaterThan(fraction, 0.2)
        XCTAssertLessThan(fraction, 0.45)
    }

    func test_isLand_recognisesKnownLandmasses() {
        let places: [String: (lat: Double, lon: Double)] = [
            "Paris": (48.85, 2.35),
            "Brasília": (-15.79, -47.88),
            "Kansas": (38.5, -98.0),
            "Sahara": (23.0, 12.0),
            "Alice Springs": (-23.7, 133.9),
            "central Siberia": (62.0, 95.0),
            "Antarctic interior": (-82.0, 0.0)
        ]
        for (name, place) in places {
            XCTAssertTrue(WorldLandMask.isLand(latitude: place.lat, longitude: place.lon),
                          "expected land at \(name)")
        }
    }

    func test_isLand_recognisesOpenOcean() {
        let places: [String: (lat: Double, lon: Double)] = [
            "mid Atlantic": (25.0, -40.0),
            "mid Pacific": (0.0, -150.0),
            "Indian Ocean": (-30.0, 80.0),
            "Southern Ocean": (-55.0, 20.0),
            "North Pole": (89.5, 0.0)
        ]
        for (name, place) in places {
            XCTAssertFalse(WorldLandMask.isLand(latitude: place.lat, longitude: place.lon),
                           "expected water at \(name)")
        }
    }

    func test_isLand_rejectsOutOfRangeCoordinates() {
        XCTAssertFalse(WorldLandMask.isLand(latitude: 91, longitude: 0))
        XCTAssertFalse(WorldLandMask.isLand(latitude: 0, longitude: 181))
        XCTAssertFalse(WorldLandMask.isLand(latitude: -90.5, longitude: -200))
    }

    func test_isLand_matchesTheLargeNationsOnTheGlobe() {
        // Only the big landmasses: at half-degree resolution small nations (Qatar, Cabo Verde)
        // legitimately fall in a water cell, and their pills float above the surface anyway.
        for name in ["brazil", "united states", "china", "russia", "australia", "argentina", "india", "canada"] {
            guard let coordinate = CountryCoordinates.location(for: name) else { continue }
            XCTAssertTrue(
                WorldLandMask.isLand(latitude: coordinate.lat, longitude: coordinate.lon),
                "\(name) pill would float over water"
            )
        }
    }
}

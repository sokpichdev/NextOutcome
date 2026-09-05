//
//  GlobeTextureTests.swift
//  NextOutcome
//

#if canImport(UIKit)
@testable import MarketsPresentation
import UIKit
import XCTest

/// Verifies the globe's emission texture actually paints continents — dots over land, plain
/// dark ocean everywhere else.
final class GlobeTextureTests: XCTestCase {
    /// The fraction of pixels in a small patch around a lat/lon that are lit by a dot, 0...1.
    private func litFraction(of image: UIImage, latitude: Double, longitude: Double) -> Double {
        guard let cgImage = image.cgImage else { return -1 }
        let width = cgImage.width, height = cgImage.height
        let patch = max(8, width / 60)
        let x = min(width - patch, max(0, Int((longitude + 180) / 360 * Double(width)) - patch / 2))
        let y = min(height - patch, max(0, Int((90 - latitude) / 180 * Double(height)) - patch / 2))

        var pixels = [UInt8](repeating: 0, count: patch * patch * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: &pixels, width: patch, height: patch, bitsPerComponent: 8,
                                      bytesPerRow: patch * 4, space: space, bitmapInfo: info) else { return -1 }
        context.draw(cgImage, in: CGRect(x: -x, y: -(height - y - patch), width: width, height: height))

        // Count pixels clearly brighter than the near-black ocean fill.
        var lit = 0
        for pixel in stride(from: 0, to: pixels.count, by: 4) {
            let luminance = (Double(pixels[pixel]) + Double(pixels[pixel + 1]) + Double(pixels[pixel + 2])) / 3 / 255
            if luminance > 0.25 { lit += 1 }
        }
        return Double(lit) / Double(patch * patch)
    }

    func test_dotTexture_lightsUpLandAndLeavesOceanDark() throws {
        let texture = GlobeSceneView.dotTexture(size: 2048)
        XCTAssertEqual(texture.size.width / texture.size.height, 2, "equirectangular textures must be 2:1")

        let land: [String: (lat: Double, lon: Double)] = [
            "Sahara": (23, 12), "central Brazil": (-12, -52), "central Asia": (45, 80)
        ]
        let ocean: [String: (lat: Double, lon: Double)] = [
            "mid Pacific": (0, -150), "mid Atlantic": (25, -40), "Indian Ocean": (-30, 80)
        ]
        for (name, place) in land {
            let value = litFraction(of: texture, latitude: place.lat, longitude: place.lon)
            XCTAssertGreaterThan(value, 0.03, "\(name) should be dotted, lit fraction was \(value)")
        }
        for (name, place) in ocean {
            let value = litFraction(of: texture, latitude: place.lat, longitude: place.lon)
            XCTAssertEqual(value, 0, "\(name) should be plain dark ocean, lit fraction was \(value)")
        }
    }
}
#endif

import XCTest
import SwiftUI
@testable import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

final class ColorTokensTests: XCTestCase {
    #if canImport(UIKit)
    private func components(_ color: Color, style: UIUserInterfaceStyle) -> (CGFloat, CGFloat, CGFloat) {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    func test_background_matchesLightAndDarkHexValues() {
        let light = components(DSColor.background, style: .light)
        let dark = components(DSColor.background, style: .dark)

        XCTAssertEqual(light.0, CGFloat(0xF7) / 255, accuracy: 0.01)
        XCTAssertEqual(light.1, CGFloat(0xF8) / 255, accuracy: 0.01)
        XCTAssertEqual(light.2, CGFloat(0xFB) / 255, accuracy: 0.01)

        XCTAssertEqual(dark.0, CGFloat(0x0B) / 255, accuracy: 0.01)
        XCTAssertEqual(dark.1, CGFloat(0x0E) / 255, accuracy: 0.01)
        XCTAssertEqual(dark.2, CGFloat(0x15) / 255, accuracy: 0.01)
    }

    func test_textPrimary_differsBetweenLightAndDark() {
        let light = components(DSColor.textPrimary, style: .light)
        let dark = components(DSColor.textPrimary, style: .dark)
        XCTAssertTrue(abs(light.0 - dark.0) > 0.1)
    }

    func test_positive_differsBetweenLightAndDark() {
        let light = components(DSColor.positive, style: .light)
        let dark = components(DSColor.positive, style: .dark)
        XCTAssertTrue(abs(light.1 - dark.1) > 0.01)
    }

    func test_accent_isUnchangedBetweenLightAndDark() {
        let light = components(DSColor.accent, style: .light)
        let dark = components(DSColor.accent, style: .dark)
        XCTAssertEqual(light.0, dark.0, accuracy: 0.001)
        XCTAssertEqual(light.1, dark.1, accuracy: 0.001)
        XCTAssertEqual(light.2, dark.2, accuracy: 0.001)
    }
    #endif
}

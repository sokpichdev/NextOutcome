import XCTest
@testable import DesignSystem

@MainActor
final class ThemeManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ThemeManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_defaultsToDarkMode_whenNoValueSaved() {
        let manager = ThemeManager(defaults: defaults)
        XCTAssertTrue(manager.isDarkMode)
    }

    func test_toggle_flipsAndPersists() {
        let manager = ThemeManager(defaults: defaults)
        manager.toggle()
        XCTAssertFalse(manager.isDarkMode)

        let restored = ThemeManager(defaults: defaults)
        XCTAssertFalse(restored.isDarkMode)
    }

    func test_toggle_twice_returnsToDark() {
        let manager = ThemeManager(defaults: defaults)
        manager.toggle()
        manager.toggle()
        XCTAssertTrue(manager.isDarkMode)
    }
}

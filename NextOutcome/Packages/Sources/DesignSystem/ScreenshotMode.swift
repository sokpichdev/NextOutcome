import Foundation

/// Presentation-only stabilisation for automated screenshot runs.
///
/// The app has no mock layer — screenshots are taken against live Polymarket data. This
/// flag freezes how that data is *presented* (animations, transient overlays, scroll
/// position) so two runs are comparable, without faking a single number.
///
/// Follows the DEBUG-only launch-argument convention already used by `-preselectCategory`
/// (`RootView`) and `-simulateGeoblock` (`TradingAccessViewModel`). Release builds always
/// report `false`, so nothing here can reach a shipping binary.
public enum ScreenshotMode {

    /// The launch argument that turns the mode on.
    public static let flag = "-screenshotMode"

    /// Whether this process was launched for a screenshot run.
    public static var isActive: Bool {
        isActive(in: ProcessInfo.processInfo.arguments)
    }

    /// Testable form of ``isActive``.
    /// - Parameter arguments: The process arguments to inspect.
    /// - Returns: Whether the flag is present. Always `false` in release builds.
    public static func isActive(in arguments: [String]) -> Bool {
        #if DEBUG
        return arguments.contains(flag)
        #else
        return false
        #endif
    }
}

import Foundation

/// Owns the app's Light/Dark theme preference and persists it across launches.
///
/// Defaults to dark mode on first launch (matching the app's original look)
/// when no preference has been saved yet. The app is expected to force its
/// whole view hierarchy to this preference via `.preferredColorScheme(_:)`
/// rather than following the device's system appearance.
@MainActor
@Observable
public final class ThemeManager {
    private let defaults: UserDefaults
    private static let key = "app.theme.isDarkMode"

    /// Whether the app is currently showing its dark palette.
    public private(set) var isDarkMode: Bool

    /// Creates the theme manager, restoring any previously saved preference.
    /// - Parameter defaults: The `UserDefaults` to persist into. Defaults to
    ///   `.standard`; inject an isolated suite in tests.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isDarkMode = defaults.object(forKey: Self.key) as? Bool ?? true
    }

    /// Flips the current theme and persists the new value.
    public func toggle() {
        isDarkMode.toggle()
        defaults.set(isDarkMode, forKey: Self.key)
    }
}

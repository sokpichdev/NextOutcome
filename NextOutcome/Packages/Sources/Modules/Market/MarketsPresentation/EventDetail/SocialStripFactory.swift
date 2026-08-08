import SwiftUI
import MarketsDomain

/// App-provided builder for a `SocialStripViewModel` given an event id, its top market's
/// condition id, and (for multi-candidate events) the full market list so the Top
/// Holders/Positions/Activity tabs can offer a per-candidate picker. Lets Event Detail load
/// the social strip without importing the Data layer.
public struct SocialStripViewModelFactory: Sendable {
    /// The closure (supplied by `AppContainer`) that builds the view model.
    private let make: @Sendable @MainActor (String, String?, [Market]) -> SocialStripViewModel

    /// Wraps a builder closure.
    /// - Parameter make: Builds a `SocialStripViewModel` from an event id, condition id, and markets.
    public init(_ make: @escaping @Sendable @MainActor (String, String?, [Market]) -> SocialStripViewModel) {
        self.make = make
    }

    /// Calls the factory like a function: `factory(eventID:conditionId:markets:)`.
    /// - Parameters:
    ///   - eventID: The event whose comments to load.
    ///   - conditionId: The top market's condition id, or `nil`.
    ///   - markets: The event's markets, for the candidate picker. Defaults to empty
    ///     (single-market screens like Market Detail, where there's no candidate to pick).
    /// - Returns: A ready-to-use `SocialStripViewModel`.
    @MainActor
    public func callAsFunction(eventID: String, conditionId: String?, markets: [Market] = []) -> SocialStripViewModel {
        make(eventID, conditionId, markets)
    }
}

/// Environment plumbing so the factory can be read with `@Environment(\.socialStripFactory)`.
private struct SocialStripFactoryKey: EnvironmentKey {
    /// No factory by default (previews/tests without a container).
    static let defaultValue: SocialStripViewModelFactory? = nil
}

public extension EnvironmentValues {
    /// The social-strip view-model factory injected by `AppContainer`; `nil` if not provided.
    var socialStripFactory: SocialStripViewModelFactory? {
        get { self[SocialStripFactoryKey.self] }
        set { self[SocialStripFactoryKey.self] = newValue }
    }
}

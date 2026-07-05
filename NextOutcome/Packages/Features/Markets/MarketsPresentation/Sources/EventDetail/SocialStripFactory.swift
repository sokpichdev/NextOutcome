import SwiftUI

/// App-provided builder for a `SocialStripViewModel` given an event id and (optionally)
/// its top market's condition id. Lets Event Detail load the social strip without
/// importing the Data layer.
public struct SocialStripViewModelFactory: Sendable {
    /// The closure (supplied by `AppContainer`) that builds the view model.
    private let make: @Sendable @MainActor (String, String?) -> SocialStripViewModel

    /// Wraps a builder closure.
    /// - Parameter make: Builds a `SocialStripViewModel` from an event id and condition id.
    public init(_ make: @escaping @Sendable @MainActor (String, String?) -> SocialStripViewModel) {
        self.make = make
    }

    /// Calls the factory like a function: `factory(eventID:conditionId:)`.
    /// - Parameters:
    ///   - eventID: The event whose comments to load.
    ///   - conditionId: The top market's condition id, or `nil`.
    /// - Returns: A ready-to-use `SocialStripViewModel`.
    @MainActor
    public func callAsFunction(eventID: String, conditionId: String?) -> SocialStripViewModel {
        make(eventID, conditionId)
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

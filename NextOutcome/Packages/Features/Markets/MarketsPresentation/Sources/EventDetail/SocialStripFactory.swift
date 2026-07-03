import SwiftUI

/// App-provided builder for a `SocialStripViewModel` given an event id and (optionally)
/// its top market's condition id. Lets Event Detail load the social strip without
/// importing the Data layer.
public struct SocialStripViewModelFactory: Sendable {
    private let make: @Sendable @MainActor (String, String?) -> SocialStripViewModel

    public init(_ make: @escaping @Sendable @MainActor (String, String?) -> SocialStripViewModel) {
        self.make = make
    }

    @MainActor
    public func callAsFunction(eventID: String, conditionId: String?) -> SocialStripViewModel {
        make(eventID, conditionId)
    }
}

private struct SocialStripFactoryKey: EnvironmentKey {
    static let defaultValue: SocialStripViewModelFactory? = nil
}

public extension EnvironmentValues {
    var socialStripFactory: SocialStripViewModelFactory? {
        get { self[SocialStripFactoryKey.self] }
        set { self[SocialStripFactoryKey.self] = newValue }
    }
}

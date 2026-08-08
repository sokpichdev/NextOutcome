//
//  TeamProfileFactory.swift
//  NextOutcome
//

import SwiftUI

/// App-provided builder for a `TeamProfileViewModel` given the tapped
/// `TeamProfileTarget`. Lets `GameCard`'s callers open a team profile without
/// importing the Data layer. Mirrors `MoversDetailViewModelFactory`.
public struct TeamProfileViewModelFactory: Sendable {
    /// The closure (supplied by `AppContainer`) that builds the view model.
    private let make: @Sendable @MainActor (TeamProfileTarget) -> TeamProfileViewModel

    /// Wraps a builder closure.
    /// - Parameter make: Builds a `TeamProfileViewModel` from a `TeamProfileTarget`.
    public init(_ make: @escaping @Sendable @MainActor (TeamProfileTarget) -> TeamProfileViewModel) {
        self.make = make
    }

    /// Calls the factory like a function: `factory(target)`.
    /// - Parameter target: The tapped team.
    /// - Returns: A ready-to-use `TeamProfileViewModel`.
    @MainActor
    public func callAsFunction(_ target: TeamProfileTarget) -> TeamProfileViewModel {
        make(target)
    }
}

/// Environment plumbing so the factory can be read with `@Environment(\.teamProfileFactory)`.
private struct TeamProfileFactoryKey: EnvironmentKey {
    /// No factory by default (previews/tests without a container).
    static let defaultValue: TeamProfileViewModelFactory? = nil
}

public extension EnvironmentValues {
    /// The team-profile view-model factory injected by `AppContainer`; `nil` if not provided.
    var teamProfileFactory: TeamProfileViewModelFactory? {
        get { self[TeamProfileFactoryKey.self] }
        set { self[TeamProfileFactoryKey.self] = newValue }
    }
}

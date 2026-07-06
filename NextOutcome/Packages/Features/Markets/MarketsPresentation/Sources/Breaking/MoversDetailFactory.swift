//
//  MoversDetailFactory.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import SwiftUI
import MarketsDomain

/// App-provided builder for a `MoversDetailViewModel` given the tapped `Mover`. Lets the
/// Breaking feed open the movers detail (which fetches the parent event and price history)
/// without importing the Data layer. Mirrors `SocialStripViewModelFactory`.
public struct MoversDetailViewModelFactory: Sendable {
    /// The closure (supplied by `AppContainer`) that builds the view model.
    private let make: @Sendable @MainActor (Mover) -> MoversDetailViewModel

    /// Wraps a builder closure.
    /// - Parameter make: Builds a `MoversDetailViewModel` from a `Mover`.
    public init(_ make: @escaping @Sendable @MainActor (Mover) -> MoversDetailViewModel) {
        self.make = make
    }

    /// Calls the factory like a function: `factory(mover)`.
    /// - Parameter mover: The mover whose detail to open.
    /// - Returns: A ready-to-use `MoversDetailViewModel`.
    @MainActor
    public func callAsFunction(_ mover: Mover) -> MoversDetailViewModel {
        make(mover)
    }
}

/// Environment plumbing so the factory can be read with `@Environment(\.moversDetailFactory)`.
private struct MoversDetailFactoryKey: EnvironmentKey {
    /// No factory by default (previews/tests without a container).
    static let defaultValue: MoversDetailViewModelFactory? = nil
}

public extension EnvironmentValues {
    /// The movers-detail view-model factory injected by `AppContainer`; `nil` if not provided.
    var moversDetailFactory: MoversDetailViewModelFactory? {
        get { self[MoversDetailFactoryKey.self] }
        set { self[MoversDetailFactoryKey.self] = newValue }
    }
}

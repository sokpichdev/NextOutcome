//
//  EsportsMatchDetailFactory.swift
//  NextOutcome
//
//  Created by Sok Pich on 10/08/2026.
//

import SwiftUI
import MarketsDomain

/// App-provided builder for an `EsportsMatchDetailViewModel` given the tapped match. Lets the
/// Esports hub open the match detail (which polls results, subscribes to the sports socket and
/// probes the broadcast) without importing the Data layer. Mirrors `MoversDetailViewModelFactory`.
public struct EsportsMatchDetailViewModelFactory: Sendable {
    /// The closure (supplied by `AppContainer`) that builds the view model.
    private let make: @Sendable @MainActor (Event, EsportsLeague?) -> EsportsMatchDetailViewModel

    /// Wraps a builder closure.
    /// - Parameter make: Builds the view model from the tapped event and its game.
    public init(_ make: @escaping @Sendable @MainActor (Event, EsportsLeague?) -> EsportsMatchDetailViewModel) {
        self.make = make
    }

    /// Calls the factory like a function: `factory(event, league)`.
    /// - Parameters:
    ///   - event: The match whose detail to open.
    ///   - league: The match's game, resolved by the hub against its catalogue.
    /// - Returns: A ready-to-use `EsportsMatchDetailViewModel`.
    @MainActor
    public func callAsFunction(_ event: Event, _ league: EsportsLeague?) -> EsportsMatchDetailViewModel {
        make(event, league)
    }
}

/// Environment plumbing so the factory can be read with `@Environment(\.esportsMatchDetailFactory)`.
private struct EsportsMatchDetailFactoryKey: EnvironmentKey {
    /// No factory by default (previews/tests without a container).
    static let defaultValue: EsportsMatchDetailViewModelFactory? = nil
}

public extension EnvironmentValues {
    /// The esports match-detail view-model factory injected by `AppContainer`; `nil` if not provided.
    var esportsMatchDetailFactory: EsportsMatchDetailViewModelFactory? {
        get { self[EsportsMatchDetailFactoryKey.self] }
        set { self[EsportsMatchDetailFactoryKey.self] = newValue }
    }
}

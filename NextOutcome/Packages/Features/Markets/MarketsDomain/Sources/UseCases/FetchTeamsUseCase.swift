//
//  FetchTeamsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

/// Loads team reference data (names, logos, colours) for a sports league.
public struct FetchTeamsUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches teams for a league.
    /// - Parameter league: The league code (e.g. "fifwc").
    /// - Returns: The league's teams.
    public func execute(league: String) async throws -> [GameTeam] {
        try await repository.fetchTeams(league: league)
    }

    /// Returns an instance whose `execute` always returns no teams. Use in unit tests.
    #if DEBUG
    public static let stub = FetchTeamsUseCase(repository: StubMarketRepository())
    #endif
}

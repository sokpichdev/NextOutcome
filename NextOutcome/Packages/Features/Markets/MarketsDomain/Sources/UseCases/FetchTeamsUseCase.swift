//
//  FetchTeamsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

public struct FetchTeamsUseCase: Sendable {
    private let repository: MarketRepository

    public init(repository: MarketRepository) {
        self.repository = repository
    }

    public func execute(league: String) async throws -> [GameTeam] {
        try await repository.fetchTeams(league: league)
    }

    /// Returns an instance whose `execute` always returns no teams. Use in unit tests.
    #if DEBUG
    public static let stub = FetchTeamsUseCase(repository: StubMarketRepository())
    #endif
}

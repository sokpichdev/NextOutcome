//
//  FetchCommentsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

public struct FetchCommentsUseCase: Sendable {
    private let repository: MarketRepository

    public init(repository: MarketRepository) {
        self.repository = repository
    }

    public func execute(eventID: String) async throws -> [Comment] {
        try await repository.comments(eventID: eventID)
    }

    #if DEBUG
    public static let stub = FetchCommentsUseCase(repository: StubMarketRepository())
    #endif
}

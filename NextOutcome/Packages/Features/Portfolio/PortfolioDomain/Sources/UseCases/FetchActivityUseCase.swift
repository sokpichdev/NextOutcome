//
//  FetchActivityUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SharedDomain

public struct FetchActivityUseCase: Sendable {
    private let repository: PortfolioRepository

    public init(repository: PortfolioRepository) {
        self.repository = repository
    }

    public func execute(address: String, cursor: String? = nil) async throws -> Page<Activity> {
        try await repository.activity(address: address, cursor: cursor)
    }
}

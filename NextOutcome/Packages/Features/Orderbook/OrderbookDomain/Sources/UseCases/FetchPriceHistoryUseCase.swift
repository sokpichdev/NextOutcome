//
//  FetchPriceHistoryUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

public struct FetchPriceHistoryUseCase: Sendable {
    private let repository: OrderbookRepository

    public init(repository: OrderbookRepository) {
        self.repository = repository
    }

    public func execute(
        assetID: String,
        interval: PriceHistoryInterval = .oneDay
    ) async throws -> [PriceHistoryPoint] {
        try await repository.priceHistory(assetID: assetID, interval: interval)
    }
}

//
//  DataPortfolioRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import Networking
import PortfolioDomain

public struct DataPortfolioRepository: PortfolioRepository {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func positions(address: String) async throws -> [Position] {
        let endpoint = Endpoint(
            host: .data,
            path: "/positions",
            query: ["user": address, "sizeThreshold": "0.1", "limit": "100"]
        )
        let dtos: [PositionDTO] = try await client.fetch(endpoint)
        return dtos.map(PositionMapper.position(from:))
    }

    public func value(address: String) async throws -> Decimal {
        let endpoint = Endpoint(host: .data, path: "/value", query: ["user": address])
        // `/value` may return an array of rows or a single object.
        if let rows: [PortfolioValueDTO] = try? await client.fetch(endpoint) {
            return rows.first?.value ?? 0
        }
        let single: PortfolioValueDTO = try await client.fetch(endpoint)
        return single.value
    }
}

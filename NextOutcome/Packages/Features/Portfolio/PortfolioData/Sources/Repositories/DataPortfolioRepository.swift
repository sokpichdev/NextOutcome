//
//  DataPortfolioRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import Networking
import PortfolioDomain
import SharedDomain

public struct DataPortfolioRepository: PortfolioRepository {
    private static let pageSize = 25
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

    public func activity(address: String, cursor: String?) async throws -> Page<Activity> {
        let offset = cursor.flatMap(Int.init) ?? 0
        let endpoint = Endpoint(
            host: .data,
            path: "/activity",
            query: ["user": address, "limit": "\(Self.pageSize)", "offset": "\(offset)"]
        )
        let dtos: [ActivityDTO] = try await client.fetch(endpoint)
        let items = dtos.enumerated().map { ActivityMapper.activity(from: $1, index: offset + $0) }
        let nextCursor = dtos.count == Self.pageSize ? "\(offset + Self.pageSize)" : nil
        return Page(items: items, nextCursor: nextCursor)
    }
}

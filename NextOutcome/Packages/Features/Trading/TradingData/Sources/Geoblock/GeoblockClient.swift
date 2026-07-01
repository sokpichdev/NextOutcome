//
//  GeoblockClient.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import Networking
import TradingDomain

/// Public geoblock pre-gate: `GET https://polymarket.com/api/geoblock`.
/// UX only — the proxy re-checks authoritatively server-side before any write.
public struct GeoblockClient: GeoblockService {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func status() async throws -> GeoblockStatus {
        let endpoint = Endpoint(host: .geoblock, path: "/api/geoblock")
        let dto: GeoblockDTO = try await client.fetch(endpoint)
        return GeoblockStatus(
            blocked: dto.blocked ?? false,
            closeOnly: dto.closeOnly ?? false,
            region: dto.region
        )
    }
}

struct GeoblockDTO: Decodable {
    let blocked: Bool?
    let closeOnly: Bool?
    let region: String?
}

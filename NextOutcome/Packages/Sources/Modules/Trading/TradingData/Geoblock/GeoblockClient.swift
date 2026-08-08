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
    /// The shared API client used to make the geoblock request.
    private let client: APIClient

    /// Creates the client.
    /// - Parameter client: The shared `APIClient` to route the request through.
    public init(client: APIClient) {
        self.client = client
    }

    /// Fetches the current geoblock status from Polymarket's public endpoint.
    /// - Returns: A `GeoblockStatus`; missing fields default to "not blocked".
    /// - Throws: A networking error if the request fails.
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

/// The raw JSON shape returned by the geoblock endpoint. All fields are optional
/// because the API may omit them; `GeoblockClient` fills in safe defaults.
struct GeoblockDTO: Decodable {
    /// Whether trading is blocked, if the API said so.
    let blocked: Bool?
    /// Whether only closing positions is allowed, if the API said so.
    let closeOnly: Bool?
    /// The detected region code, if provided.
    let region: String?
}

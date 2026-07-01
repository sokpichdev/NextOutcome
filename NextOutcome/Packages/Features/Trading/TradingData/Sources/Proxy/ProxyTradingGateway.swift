//
//  ProxyTradingGateway.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import TradingDomain

public struct TradingProxyConfig: Sendable {
    public let baseURL: URL
    public init(baseURL: URL) { self.baseURL = baseURL }
}

/// REST client for our backend proxy. The proxy holds L2 creds, adds HMAC headers,
/// and forwards to CLOB — this client only ever sends **L1-signed** payloads + the
/// session token. No cryptography happens here.
public struct ProxyTradingGateway: TradingGateway {
    private let config: TradingProxyConfig
    private let session: URLSession
    private let store: CredentialStore

    public init(config: TradingProxyConfig, store: CredentialStore, session: URLSession = .shared) {
        self.config = config
        self.session = session
        self.store = store
    }

    public func deriveKey(address: String, attestation: String) async throws {
        _ = try await send(
            "POST", "/v1/session/derive-key",
            body: ["address": address, "l1Signature": attestation]
        )
    }

    public func placeOrder(_ order: SignedOrder, idempotencyKey: String) async throws -> String {
        let body: [String: Any] = [
            "idempotencyKey": idempotencyKey,
            "signedOrder": [
                "tokenId": order.tokenID,
                "side": order.side.rawValue,
                "price": "\(order.price)",
                "size": "\(order.size)",
                "maker": order.maker,
                "salt": order.salt,
                "expiration": order.expiration,
                "signature": order.signature,
                "signatureType": order.signatureType,
            ],
        ]
        let data = try await send("POST", "/v1/orders", body: body)
        struct Response: Decodable { let orderId: String }
        return try JSONDecoder().decode(Response.self, from: data).orderId
    }

    public func cancelOrder(id: String) async throws {
        _ = try await send("DELETE", "/v1/orders/\(id)", body: nil)
    }

    // MARK: - Transport

    @discardableResult
    private func send(_ method: String, _ path: String, body: [String: Any]?) async throws -> Data {
        guard let token = try store.loadSessionToken() else { throw WalletError.notAuthenticated }
        var request = URLRequest(url: config.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw WalletError.rejected("proxy \(status)")
        }
        return data
    }
}

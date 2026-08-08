//
//  ProxyTradingGateway.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import TradingDomain

/// Configuration for talking to the backend trading proxy.
public struct TradingProxyConfig: Sendable {
    /// The proxy's base URL; request paths are appended to this.
    public let baseURL: URL
    /// Creates the config.
    /// - Parameter baseURL: The proxy's base URL.
    public init(baseURL: URL) { self.baseURL = baseURL }
}

/// REST client for our backend proxy. The proxy holds L2 creds, adds HMAC headers,
/// and forwards to CLOB — this client only ever sends **L1-signed** payloads + the
/// session token. No cryptography happens here.
public struct ProxyTradingGateway: TradingGateway {
    /// Where the proxy lives.
    private let config: TradingProxyConfig
    /// The URLSession used for the raw HTTP calls (swappable in tests).
    private let session: URLSession
    /// Supplies the bearer session token attached to every request.
    private let store: CredentialStore

    /// Creates the gateway.
    /// - Parameters:
    ///   - config: The proxy configuration (base URL).
    ///   - store: Where the session token is read from for auth.
    ///   - session: The URLSession to use. Defaults to `.shared`.
    public init(config: TradingProxyConfig, store: CredentialStore, session: URLSession = .shared) {
        self.config = config
        self.session = session
        self.store = store
    }

    /// Establishes the trading session by sending the wallet address and its L1 signature
    /// so the proxy can derive the L2 key it holds on the user's behalf.
    /// - Parameters:
    ///   - address: The wallet address.
    ///   - attestation: The L1 (hex) signature proving ownership.
    /// - Throws: `WalletError` if unauthenticated or the proxy rejects the request.
    public func deriveKey(address: String, attestation: String) async throws {
        _ = try await send(
            "POST", "/v1/session/derive-key",
            body: ["address": address, "l1Signature": attestation]
        )
    }

    /// Sends a signed order to the proxy, which forwards it to CLOB.
    ///
    /// The `idempotencyKey` lets the proxy de-duplicate: if the request is retried after
    /// a network hiccup, the same key ensures only one order is actually placed.
    /// - Parameters:
    ///   - order: The L1-signed order payload.
    ///   - idempotencyKey: A unique key guarding against duplicate placement.
    /// - Returns: The proxy-assigned order ID.
    /// - Throws: `WalletError` if unauthenticated or rejected.
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

    /// Cancels a previously-placed order by ID.
    /// - Parameter id: The order ID returned from `placeOrder`.
    /// - Throws: `WalletError` if unauthenticated or rejected.
    public func cancelOrder(id: String) async throws {
        _ = try await send("DELETE", "/v1/orders/\(id)", body: nil)
    }

    // MARK: - Transport

    /// Shared helper that performs an authenticated JSON request to the proxy.
    ///
    /// Attaches the bearer session token, encodes the optional JSON body, and maps any
    /// non-2xx response to a `WalletError.rejected`.
    /// - Parameters:
    ///   - method: The HTTP verb ("POST", "DELETE", …).
    ///   - path: The path appended to the proxy base URL.
    ///   - body: An optional JSON dictionary to send as the request body.
    /// - Returns: The raw response body data.
    /// - Throws: `WalletError.notAuthenticated` if no token is stored, or
    ///   `WalletError.rejected` on a non-2xx status.
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

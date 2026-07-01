//
//  TradingPorts.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

public enum WalletError: Error, Equatable {
    case signerUnavailable       // no vetted secp256k1/EIP-712 signer wired in yet
    case notAuthenticated
    case geoblocked(region: String?)
    case rejected(String)
}

public struct GeoblockStatus: Hashable, Sendable {
    public let blocked: Bool
    public let closeOnly: Bool
    public let region: String?

    public init(blocked: Bool, closeOnly: Bool, region: String?) {
        self.blocked = blocked
        self.closeOnly = closeOnly
        self.region = region
    }
}

/// EIP-712 L1 signing on-device. The concrete implementation is supplied by a
/// **vetted crypto library under security review** — never hand-rolled here.
public protocol WalletSigner: Sendable {
    /// Signs the connect-wallet attestation, returning a hex signature.
    func signAttestation(address: String) async throws -> String
    /// Builds + L1-signs an order from a ticket.
    func signOrder(_ ticket: OrderTicket, maker: String) async throws -> SignedOrder
}

/// Secure storage for the app↔proxy session token (and only that — never L2 secrets,
/// which live server-side). Backed by Keychain.
public protocol CredentialStore: Sendable {
    func save(sessionToken: String) throws
    func loadSessionToken() throws -> String?
    func clear() throws
}

/// The app's view of our backend proxy. The proxy adds L2 HMAC and forwards to CLOB.
public protocol TradingGateway: Sendable {
    func deriveKey(address: String, attestation: String) async throws
    func placeOrder(_ order: SignedOrder, idempotencyKey: String) async throws -> String
    func cancelOrder(id: String) async throws
}

/// Authoritative-ish geoblock pre-gate (the proxy re-checks server-side before any write).
public protocol GeoblockService: Sendable {
    func status() async throws -> GeoblockStatus
}

//
//  TradingPorts.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Things that can go wrong in the wallet/trading flow. Callers switch on these to show
/// the right message or gate the UI.
public enum WalletError: Error, Equatable {
    /// No vetted on-device signer has been wired in yet, so signing can't happen.
    case signerUnavailable       // no vetted secp256k1/EIP-712 signer wired in yet
    /// The user has no active session — they need to connect their wallet first.
    case notAuthenticated
    /// Trading is blocked in the user's region.
    /// - Parameter region: The detected region code, if known.
    case geoblocked(region: String?)
    /// The proxy/exchange rejected the request.
    /// - Parameter String: The rejection reason.
    case rejected(String)
}

/// Whether the current user is allowed to trade, per Polymarket's geographic rules.
public struct GeoblockStatus: Hashable, Sendable {
    /// `true` if the user is fully blocked from trading.
    public let blocked: Bool
    /// `true` if the user may only close existing positions, not open new ones.
    public let closeOnly: Bool
    /// The detected region code, if the service reported one.
    public let region: String?

    /// Creates a geoblock status snapshot.
    /// - Parameters:
    ///   - blocked: Whether trading is fully blocked.
    ///   - closeOnly: Whether only closing positions is allowed.
    ///   - region: The detected region, if any.
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
    /// - Parameter address: The wallet address to attest.
    /// - Returns: The hex-encoded signature.
    /// - Throws: A `WalletError` if signing is unavailable or rejected.
    func signAttestation(address: String) async throws -> String
    /// Builds and L1-signs an order from the user's ticket.
    /// - Parameters:
    ///   - ticket: The unsigned order intent.
    ///   - maker: The signing wallet address.
    /// - Returns: A fully-signed order ready for the proxy.
    /// - Throws: A `WalletError` if signing fails.
    func signOrder(_ ticket: OrderTicket, maker: String) async throws -> SignedOrder
}

/// Secure storage for the app↔proxy session token (and only that — never L2 secrets,
/// which live server-side). Backed by Keychain.
public protocol CredentialStore: Sendable {
    /// Persists the session token securely in the Keychain.
    /// - Parameter sessionToken: The token to store.
    func save(sessionToken: String) throws
    /// Reads the stored session token, or `nil` if none is saved.
    func loadSessionToken() throws -> String?
    /// Deletes any stored session token (e.g. on logout).
    func clear() throws
}

/// The app's view of our backend proxy. The proxy adds L2 HMAC and forwards to CLOB.
public protocol TradingGateway: Sendable {
    /// Establishes the trading session by proving wallet ownership to the proxy.
    /// - Parameters:
    ///   - address: The wallet address.
    ///   - attestation: The signed attestation from `WalletSigner`.
    func deriveKey(address: String, attestation: String) async throws
    /// Submits a signed order to the proxy for forwarding to CLOB.
    /// - Parameters:
    ///   - order: The signed order.
    ///   - idempotencyKey: A unique key so retries don't place duplicate orders.
    /// - Returns: The server-assigned order ID.
    func placeOrder(_ order: SignedOrder, idempotencyKey: String) async throws -> String
    /// Cancels a previously-placed order.
    /// - Parameter id: The order ID returned by `placeOrder`.
    func cancelOrder(id: String) async throws
}

/// Authoritative-ish geoblock pre-gate (the proxy re-checks server-side before any write).
public protocol GeoblockService: Sendable {
    /// Fetches the current user's geoblock status.
    /// - Returns: Whether trading is blocked / close-only, plus the region.
    func status() async throws -> GeoblockStatus
}

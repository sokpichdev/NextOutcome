//
//  UnavailableWalletSigner.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import TradingDomain

/// Placeholder signer. Real secp256k1 / EIP-712 signing requires a **vetted crypto
/// dependency and a security review** (see docs/phase-4-wallet-proxy-design.md).
/// Until that lands, every signing call fails loudly rather than producing an unsafe
/// or fake signature. Trading surfaces must treat `.signerUnavailable` as "not yet enabled".
public struct UnavailableWalletSigner: WalletSigner {
    /// Creates the placeholder signer. Takes no dependencies.
    public init() {}

    /// Always fails: real signing isn't enabled yet.
    /// - Throws: `WalletError.signerUnavailable`.
    public func signAttestation(address: String) async throws -> String {
        throw WalletError.signerUnavailable
    }

    /// Always fails: real signing isn't enabled yet.
    /// - Throws: `WalletError.signerUnavailable`.
    public func signOrder(_ ticket: OrderTicket, maker: String) async throws -> SignedOrder {
        throw WalletError.signerUnavailable
    }
}

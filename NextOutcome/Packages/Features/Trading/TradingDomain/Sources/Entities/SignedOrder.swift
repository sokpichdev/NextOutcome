//
//  SignedOrder.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// An order built and **L1-signed on-device**, ready to hand to the proxy.
/// The proxy attaches L2 HMAC headers and forwards to CLOB — it cannot alter the
/// signed payload without invalidating the signature.
public struct SignedOrder: Hashable, Sendable {
    /// The CLOB token (outcome) being traded.
    public let tokenID: String
    /// Buy or sell.
    public let side: OrderSide
    /// Price per share as a probability (0…1).
    public let price: Decimal
    /// Number of shares.
    public let size: Decimal
    /// The wallet address that signed and owns this order.
    public let maker: String            // wallet address
    /// A random unique value baked into the signature so identical orders produce
    /// different signatures and can't be replayed.
    public let salt: String
    /// When the order expires, as a Unix timestamp in seconds.
    public let expiration: Int          // unix seconds
    /// The EIP-712 cryptographic signature (hex) proving the maker authorized this order.
    public let signature: String        // EIP-712 signature (hex)
    /// Which signature scheme was used (e.g. `POLY_1271` for smart-contract wallets).
    public let signatureType: Int       // e.g. POLY_1271

    /// Creates a fully-signed order. Normally built by a signer, not by hand.
    /// - Parameters:
    ///   - tokenID: The outcome token being traded.
    ///   - side: Buy or sell.
    ///   - price: Price per share (0…1).
    ///   - size: Number of shares.
    ///   - maker: The signing wallet address.
    ///   - salt: Unique anti-replay value.
    ///   - expiration: Expiry as a Unix timestamp (seconds).
    ///   - signature: The EIP-712 signature hex string.
    ///   - signatureType: The signature scheme identifier.
    public init(
        tokenID: String, side: OrderSide, price: Decimal, size: Decimal,
        maker: String, salt: String, expiration: Int,
        signature: String, signatureType: Int
    ) {
        self.tokenID = tokenID
        self.side = side
        self.price = price
        self.size = size
        self.maker = maker
        self.salt = salt
        self.expiration = expiration
        self.signature = signature
        self.signatureType = signatureType
    }
}

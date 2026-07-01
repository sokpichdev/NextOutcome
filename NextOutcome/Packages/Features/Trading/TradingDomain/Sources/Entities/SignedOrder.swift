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
    public let tokenID: String
    public let side: OrderSide
    public let price: Decimal
    public let size: Decimal
    public let maker: String            // wallet address
    public let salt: String
    public let expiration: Int          // unix seconds
    public let signature: String        // EIP-712 signature (hex)
    public let signatureType: Int       // e.g. POLY_1271

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

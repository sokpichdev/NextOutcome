//
//  WalletAddress.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// A validated EVM address (`0x` + 40 hex chars). Normalized to lowercase.
public struct WalletAddress: Hashable, Sendable {
    /// The normalized (lowercased, `0x`-prefixed) address string.
    public let value: String

    /// Creates a wallet address if `raw` is a valid EVM address, otherwise returns `nil`.
    ///
    /// Validation: trims whitespace, lowercases, then requires a `0x` prefix followed by
    /// exactly 40 hexadecimal characters. This failable initializer means invalid input is
    /// rejected at the type boundary rather than flowing deeper into the app.
    /// - Parameter raw: The user-entered or stored address string.
    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.hasPrefix("0x") else { return nil }
        let hex = trimmed.dropFirst(2)
        guard hex.count == 40, hex.allSatisfy({ $0.isHexDigit }) else { return nil }
        self.value = trimmed
    }
}

//
//  WalletAddress.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// A validated EVM address (`0x` + 40 hex chars). Normalized to lowercase.
public struct WalletAddress: Hashable, Sendable {
    public let value: String

    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.hasPrefix("0x") else { return nil }
        let hex = trimmed.dropFirst(2)
        guard hex.count == 40, hex.allSatisfy({ $0.isHexDigit }) else { return nil }
        self.value = trimmed
    }
}

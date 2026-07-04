//
//  Holder.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// A top holder of a market's outcome token.
public struct Holder: Identifiable, Hashable {
    /// The holder's proxy wallet address (also this row's identity).
    public let id: String          // proxy wallet
    /// The holder's display name.
    public let name: String
    /// The holder's avatar image, if any.
    public let profileImageURL: URL?
    /// Which outcome they hold.
    public let outcome: String
    /// How many shares they hold.
    public let shares: Decimal

    /// Creates a holder row.
    public init(id: String, name: String, profileImageURL: URL?, outcome: String, shares: Decimal) {
        self.id = id
        self.name = name
        self.profileImageURL = profileImageURL
        self.outcome = outcome
        self.shares = shares
    }
}

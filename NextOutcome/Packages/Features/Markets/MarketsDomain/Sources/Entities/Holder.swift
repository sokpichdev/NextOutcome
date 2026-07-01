//
//  Holder.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// A top holder of a market's outcome token.
public struct Holder: Identifiable, Hashable {
    public let id: String          // proxy wallet
    public let name: String
    public let profileImageURL: URL?
    public let outcome: String
    public let shares: Decimal

    public init(id: String, name: String, profileImageURL: URL?, outcome: String, shares: Decimal) {
        self.id = id
        self.name = name
        self.profileImageURL = profileImageURL
        self.outcome = outcome
        self.shares = shares
    }
}

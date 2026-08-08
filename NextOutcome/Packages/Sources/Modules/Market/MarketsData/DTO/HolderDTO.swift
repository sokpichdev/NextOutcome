//
//  HolderDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Data API `/holders` groups top holders by outcome token:
/// `[{ "token": "...", "holders": [{...}] }]`.
struct HolderGroupDTO: Decodable {
    /// The holders belonging to one outcome token.
    let holders: [HolderDTO]
}

/// One holder row within a group.
struct HolderDTO: Decodable {
    /// The holder's proxy wallet address.
    let proxyWallet: String?
    /// The holder's display name, if any.
    let name: String?
    /// A generated pseudonym, used when `name` is absent.
    let pseudonym: String?
    /// The holder's avatar URL string.
    let profileImage: String?
    /// Which outcome index they hold.
    let outcomeIndex: Int?
    /// The holding size (from `amount`, falling back to `shares`).
    let amount: Decimal

    /// JSON keys, including the alternate `shares` amount key.
    enum CodingKeys: String, CodingKey {
        case proxyWallet, name, pseudonym, profileImage, outcomeIndex
        case amount, shares
    }

    /// Tolerant decoder resolving the amount from `amount` or `shares`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        proxyWallet = try? c.decode(String.self, forKey: .proxyWallet)
        name = try? c.decode(String.self, forKey: .name)
        pseudonym = try? c.decode(String.self, forKey: .pseudonym)
        profileImage = try? c.decode(String.self, forKey: .profileImage)
        outcomeIndex = try? c.decode(Int.self, forKey: .outcomeIndex)
        amount = DTODecoding.decimal(c, .amount).nonZeroOr(DTODecoding.decimal(c, .shares))
    }
}

private extension Decimal {
    /// Returns `self` if non-zero, otherwise `fallback` — used to pick the first populated
    /// amount field.
    func nonZeroOr(_ fallback: Decimal) -> Decimal { self == 0 ? fallback : self }
}

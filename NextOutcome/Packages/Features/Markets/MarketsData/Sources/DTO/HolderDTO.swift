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
    let holders: [HolderDTO]
}

struct HolderDTO: Decodable {
    let proxyWallet: String?
    let name: String?
    let pseudonym: String?
    let profileImage: String?
    let outcomeIndex: Int?
    let amount: Decimal

    enum CodingKeys: String, CodingKey {
        case proxyWallet, name, pseudonym, profileImage, outcomeIndex
        case amount, shares
    }

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
    func nonZeroOr(_ fallback: Decimal) -> Decimal { self == 0 ? fallback : self }
}

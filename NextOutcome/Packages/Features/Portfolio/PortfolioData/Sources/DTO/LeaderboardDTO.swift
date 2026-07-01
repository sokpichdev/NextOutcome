//
//  LeaderboardDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Data API `/closed-positions` row.
struct ClosedPositionDTO: Decodable {
    let asset: String?
    let conditionId: String?
    let title: String?
    let slug: String?
    let outcome: String?
    let icon: String?
    let realizedPnl: Decimal
    let percentRealizedPnl: Decimal
    let timestamp: Double

    enum CodingKeys: String, CodingKey {
        case asset, conditionId, title, slug, outcome, icon
        case realizedPnl, percentRealizedPnl, timestamp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        asset = try? c.decode(String.self, forKey: .asset)
        conditionId = try? c.decode(String.self, forKey: .conditionId)
        title = try? c.decode(String.self, forKey: .title)
        slug = try? c.decode(String.self, forKey: .slug)
        outcome = try? c.decode(String.self, forKey: .outcome)
        icon = try? c.decode(String.self, forKey: .icon)
        realizedPnl = PortfolioDecoding.decimal(c, .realizedPnl)
        percentRealizedPnl = PortfolioDecoding.decimal(c, .percentRealizedPnl)
        timestamp = (try? c.decode(Double.self, forKey: .timestamp)) ?? 0
    }
}

/// Data API `/v1/leaderboard` row.
struct LeaderboardEntryDTO: Decodable {
    let proxyWallet: String?
    let name: String?
    let pseudonym: String?
    let profileImage: String?
    let amount: Decimal

    enum CodingKeys: String, CodingKey {
        case proxyWallet, name, pseudonym, profileImage
        case amount, volume, profit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        proxyWallet = try? c.decode(String.self, forKey: .proxyWallet)
        name = try? c.decode(String.self, forKey: .name)
        pseudonym = try? c.decode(String.self, forKey: .pseudonym)
        profileImage = try? c.decode(String.self, forKey: .profileImage)
        // The ranked value may arrive under `amount`, `volume`, or `profit`.
        amount = PortfolioDecoding.decimal(c, .amount)
            .nonZeroOr(PortfolioDecoding.decimal(c, .volume))
            .nonZeroOr(PortfolioDecoding.decimal(c, .profit))
    }
}

private extension Decimal {
    func nonZeroOr(_ fallback: Decimal) -> Decimal { self == 0 ? fallback : self }
}

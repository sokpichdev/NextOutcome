//
//  LeaderboardDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Data API `/closed-positions` row.
struct ClosedPositionDTO: Decodable {
    /// The outcome token id.
    let asset: String?
    /// The market's condition id.
    let conditionId: String?
    /// The market title.
    let title: String?
    /// The market's URL slug.
    let slug: String?
    /// The outcome held.
    let outcome: String?
    /// The market icon URL string.
    let icon: String?
    /// Realized dollar PnL.
    let realizedPnl: Decimal
    /// Realized percent PnL.
    let percentRealizedPnl: Decimal
    /// Unix timestamp of the close, in seconds.
    let timestamp: Double

    /// JSON keys for `ClosedPositionDTO`.
    enum CodingKeys: String, CodingKey {
        case asset, conditionId, title, slug, outcome, icon
        case realizedPnl, percentRealizedPnl, timestamp
    }

    /// Custom decoder tolerating missing strings and number-or-string numeric fields.
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
    /// The trader's proxy wallet address.
    let proxyWallet: String?
    /// The trader's display name, if any.
    let name: String?
    /// A generated pseudonym, used when `name` is absent.
    let pseudonym: String?
    /// The trader's avatar URL string.
    let profileImage: String?
    /// The ranking amount (see the custom decoder for how it's resolved).
    let amount: Decimal

    /// JSON keys, including the alternate `volume`/`profit` amount keys.
    enum CodingKeys: String, CodingKey {
        case proxyWallet, name, pseudonym, profileImage
        case amount, volume, profit
    }

    /// Custom decoder that resolves the ranked value from whichever of `amount`, `volume`,
    /// or `profit` the API populated.
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
    /// Returns `self` if it's non-zero, otherwise `fallback` — used to pick the first
    /// populated amount field.
    func nonZeroOr(_ fallback: Decimal) -> Decimal { self == 0 ? fallback : self }
}

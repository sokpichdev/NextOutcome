//
//  LeaderboardMapper.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import PortfolioDomain

/// Converts the closed-position and leaderboard DTOs into their domain types, including
/// building a friendly display name from whatever identity fields the API provides.
enum LeaderboardMapper {
    /// Maps one closed-position DTO to a domain `ClosedPosition`.
    /// - Parameters:
    ///   - dto: The decoded closed-position row.
    ///   - index: The row index, used as an id fallback.
    /// - Returns: The domain closed position.
    static func closedPosition(from dto: ClosedPositionDTO, index: Int) -> ClosedPosition {
        ClosedPosition(
            id: dto.conditionId ?? dto.asset ?? "closed-\(index)",
            title: dto.title ?? "Untitled market",
            slug: dto.slug ?? "",
            outcome: dto.outcome ?? "",
            iconURL: dto.icon.flatMap(URL.init(string:)),
            realizedPnl: dto.realizedPnl,
            percentRealizedPnl: dto.percentRealizedPnl,
            timestamp: Date(timeIntervalSince1970: dto.timestamp)
        )
    }

    /// Maps one leaderboard DTO to a domain `LeaderboardEntry`, assigning the rank.
    /// - Parameters:
    ///   - dto: The decoded leaderboard row.
    ///   - rank: The 1-based rank to assign.
    /// - Returns: The domain leaderboard entry.
    static func entry(from dto: LeaderboardEntryDTO, rank: Int) -> LeaderboardEntry {
        LeaderboardEntry(
            id: dto.proxyWallet ?? "rank-\(rank)",
            rank: rank,
            name: displayName(dto),
            profileImageURL: dto.profileImage.flatMap(URL.init(string:)),
            amount: dto.amount
        )
    }

    /// Picks a display name, preferring the real name, then the pseudonym, then a
    /// shortened `0x1234…abcd` form of the wallet address.
    private static func displayName(_ dto: LeaderboardEntryDTO) -> String {
        if let name = dto.name, !name.isEmpty { return name }
        if let pseudonym = dto.pseudonym, !pseudonym.isEmpty { return pseudonym }
        guard let wallet = dto.proxyWallet, wallet.count > 10 else { return dto.proxyWallet ?? "Anonymous" }
        return "\(wallet.prefix(6))…\(wallet.suffix(4))"
    }
}

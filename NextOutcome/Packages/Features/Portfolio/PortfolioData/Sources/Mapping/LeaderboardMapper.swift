//
//  LeaderboardMapper.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import PortfolioDomain

enum LeaderboardMapper {
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

    static func entry(from dto: LeaderboardEntryDTO, rank: Int) -> LeaderboardEntry {
        LeaderboardEntry(
            id: dto.proxyWallet ?? "rank-\(rank)",
            rank: rank,
            name: displayName(dto),
            profileImageURL: dto.profileImage.flatMap(URL.init(string:)),
            amount: dto.amount
        )
    }

    private static func displayName(_ dto: LeaderboardEntryDTO) -> String {
        if let name = dto.name, !name.isEmpty { return name }
        if let pseudonym = dto.pseudonym, !pseudonym.isEmpty { return pseudonym }
        guard let wallet = dto.proxyWallet, wallet.count > 10 else { return dto.proxyWallet ?? "Anonymous" }
        return "\(wallet.prefix(6))…\(wallet.suffix(4))"
    }
}

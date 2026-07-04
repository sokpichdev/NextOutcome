//
//  PositionMapper.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import PortfolioDomain

/// Converts a `PositionDTO` (network shape) into the domain `Position`, filling in
/// fallbacks for missing titles/slugs and parsing the icon URL.
enum PositionMapper {
    /// Maps one position DTO to a domain `Position`.
    /// - Parameter dto: The decoded position row.
    /// - Returns: The domain position.
    static func position(from dto: PositionDTO) -> Position {
        Position(
            id: dto.asset,
            conditionId: dto.conditionId,
            title: dto.title ?? "Untitled market",
            slug: dto.slug ?? "",
            outcome: dto.outcome ?? "",
            iconURL: dto.icon.flatMap(URL.init(string:)),
            size: dto.size,
            avgPrice: dto.avgPrice,
            curPrice: dto.curPrice,
            currentValue: dto.currentValue,
            cashPnl: dto.cashPnl,
            percentPnl: dto.percentPnl,
            redeemable: dto.redeemable
        )
    }
}

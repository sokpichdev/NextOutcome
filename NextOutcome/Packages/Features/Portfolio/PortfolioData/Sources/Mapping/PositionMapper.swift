//
//  PositionMapper.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import PortfolioDomain

enum PositionMapper {
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

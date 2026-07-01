//
//  ActivityMapper.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import PortfolioDomain

enum ActivityMapper {
    static func activity(from dto: ActivityDTO, index: Int) -> Activity {
        Activity(
            id: dto.transactionHash.map { "\($0)-\(index)" } ?? "\(dto.conditionId ?? "act")-\(index)",
            kind: kind(type: dto.type, side: dto.side),
            title: dto.title ?? "Untitled market",
            slug: dto.slug ?? "",
            outcome: dto.outcome ?? "",
            iconURL: dto.icon.flatMap(URL.init(string:)),
            size: dto.size,
            usdcSize: dto.usdcSize,
            price: dto.price,
            timestamp: Date(timeIntervalSince1970: dto.timestamp)
        )
    }

    static func kind(type: String?, side: String?) -> ActivityKind {
        switch type?.uppercased() {
        case "TRADE":
            return side?.uppercased() == "SELL" ? .sell : .buy
        case "SPLIT": return .split
        case "MERGE": return .merge
        case "REDEEM": return .redeem
        case "REWARD": return .reward
        case "CONVERSION": return .conversion
        default: return .other
        }
    }
}

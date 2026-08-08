//
//  ActivityMapper.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import PortfolioDomain

/// Converts an `ActivityDTO` into the domain `Activity`, synthesizing a stable id and
/// mapping the raw type/side strings to an `ActivityKind`.
enum ActivityMapper {
    /// Maps one activity DTO to a domain `Activity`.
    /// - Parameters:
    ///   - dto: The decoded activity row.
    ///   - index: The row's position in the page, used to disambiguate ids.
    /// - Returns: The domain activity.
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

    /// Maps the API's `type` (and, for trades, `side`) to an `ActivityKind`.
    /// - Parameters:
    ///   - type: The raw activity type string (e.g. "TRADE", "REDEEM").
    ///   - side: The trade side ("BUY"/"SELL"), relevant only for `TRADE`.
    /// - Returns: The matching `ActivityKind`, defaulting to `.other`.
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

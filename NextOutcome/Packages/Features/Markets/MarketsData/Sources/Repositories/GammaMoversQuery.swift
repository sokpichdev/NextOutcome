//
//  GammaMoversQuery.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

/// Pure, testable query builder for the Breaking feed's `/markets` movers request.
/// Kept separate from `GammaMarketRepository` so the query shape can be unit-tested without
/// a network round-trip, mirroring `GammaEventQuery`.
public enum GammaMoversQuery {
    /// Rows fetched per direction (gainers + losers) before `MoverRanking` merges them.
    private static let pageSize = 25
    /// 24h volume floor (dollars) applied server-side to drop illiquid noise before it ever
    /// reaches the client-side denoise pass.
    private static let volumeFloor = "10000"

    /// Builds the query dictionary for one direction of the movers list.
    /// - Parameters:
    ///   - tagID: An optional category tag filter (`nil` = all categories).
    ///   - ascending: `true` for the biggest 24h losers, `false` for the biggest gainers —
    ///     Gamma can only sort `oneDayPriceChange` in one direction per request.
    /// - Returns: The query dictionary.
    public static func params(tagID: String?, ascending: Bool) -> [String: String] {
        var query: [String: String] = [
            "closed": "false",
            "active": "true",
            "order": "oneDayPriceChange",
            "ascending": ascending ? "true" : "false",
            "limit": "\(pageSize)",
            "volume_num_min": volumeFloor,
        ]
        if let tagID { query["tag_id"] = tagID }
        return query
    }
}

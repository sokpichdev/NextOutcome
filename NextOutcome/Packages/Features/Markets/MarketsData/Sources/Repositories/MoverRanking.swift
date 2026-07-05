//
//  MoverRanking.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import Foundation
import MarketsDomain

/// Pure, testable ranking pass for the Breaking feed: de-dupes, drops near-resolved noise and
/// rows with no parent event, and sorts by the magnitude of the 24h move (volume breaks ties).
/// Kept separate from `GammaMarketRepository` so the ranking rules can be unit-tested without
/// a network round-trip.
public enum MoverRanking {
    /// The number of movers returned to the Breaking feed after ranking.
    private static let limit = 30
    /// Probability band used to denoise the movers list: markets outside it are near-resolved
    /// (weather markets pinned at ~99.9%, degenerate same-day sports at ~0.1%) and flood the
    /// price-change extremes without being interesting. Tunable — widening it lets more
    /// high-confidence movers through at the cost of more resolved-market noise.
    private static let minProbability: Decimal = 0.03
    private static let maxProbability: Decimal = 0.97

    /// Ranks a combined (losers + gainers) batch of movers into the final Breaking feed list.
    /// - Parameter movers: The mapped movers, in any order, possibly containing duplicates
    ///   (a market can appear in both the losers and gainers page in edge cases).
    /// - Returns: Up to `limit` movers, de-duped, denoised, and sorted by 24h move magnitude.
    public static func rank(_ movers: [Mover]) -> [Mover] {
        var seen = Set<String>()
        var kept: [Mover] = []
        for mover in movers {
            guard !mover.eventSlug.isEmpty else { continue }
            guard mover.probability >= minProbability else { continue }
            guard mover.probability <= maxProbability else { continue }
            guard seen.insert(mover.id).inserted else { continue }
            kept.append(mover)
        }
        kept.sort { lhs, rhs in
            if lhs.magnitude == rhs.magnitude { return lhs.volume24h > rhs.volume24h }
            return lhs.magnitude > rhs.magnitude
        }
        return Array(kept.prefix(limit))
    }
}

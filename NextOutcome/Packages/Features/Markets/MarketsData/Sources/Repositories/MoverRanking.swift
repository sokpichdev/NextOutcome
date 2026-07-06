//
//  MoverRanking.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import Foundation
import MarketsDomain

/// Pure, testable ranking pass for the Breaking feed: de-dupes, drops near-resolved noise and
/// rows with no parent event, collapses same-event markets and same-topic markets from
/// *different* events down to a single biggest mover, and sorts by the magnitude of the 24h
/// move (volume breaks ties). Kept separate from `GammaMarketRepository` so the ranking rules
/// can be unit-tested without a network round-trip.
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
    ///
    /// Two passes collapse duplicate stories:
    /// 1. **Same event.** Events with several sibling markets (e.g. "will X happen by
    ///    July 7 / July 8 / July 9?") commonly place more than one of their markets among the
    ///    biggest movers — collapsed to that event's single biggest mover.
    /// 2. **Same topic, different event.** Polymarket sometimes lists what's really the same
    ///    real-world question as two separate events (e.g. "GPT-5.6 released by July 7, 2026?"
    ///    and "Will GPT-5.6 be released on July 7, 2026?" are different event ids for the same
    ///    story) — collapsed via `MoverTopicKey` (subject + date) to the biggest mover.
    /// - Parameter movers: The mapped movers, in any order, possibly containing duplicates
    ///   (a market can appear in both the losers and gainers page in edge cases).
    /// - Returns: Up to `limit` movers, de-duped, denoised, one per story, sorted by 24h move magnitude.
    public static func rank(_ movers: [Mover]) -> [Mover] {
        let perEvent = collapseByKey(filterValid(movers)) { $0.eventSlug }
        let perTopic = collapseByKey(perEvent) { MoverTopicKey.key(for: $0.question) ?? "event:\($0.eventSlug)" }
        let sorted = perTopic.sorted(by: isBigger)
        return Array(sorted.prefix(limit))
    }

    /// De-dupes by id and drops rows with no parent event or a near-resolved probability.
    private static func filterValid(_ movers: [Mover]) -> [Mover] {
        var seen = Set<String>()
        return movers.filter { mover in
            guard !mover.eventSlug.isEmpty else { return false }
            guard mover.probability >= minProbability else { return false }
            guard mover.probability <= maxProbability else { return false }
            return seen.insert(mover.id).inserted
        }
    }

    /// Groups movers by a key and keeps only the biggest-move mover per group, preserving each
    /// group's first-seen order.
    private static func collapseByKey(_ movers: [Mover], key: (Mover) -> String) -> [Mover] {
        var best: [String: Mover] = [:]
        var order: [String] = []
        for mover in movers {
            let k = key(mover)
            if let existing = best[k] {
                if isBigger(mover, than: existing) { best[k] = mover }
            } else {
                best[k] = mover
                order.append(k)
            }
        }
        return order.compactMap { best[$0] }
    }

    /// Ranking comparator: bigger 24h move wins; equal moves fall back to higher 24h volume.
    private static func isBigger(_ lhs: Mover, than rhs: Mover) -> Bool {
        if lhs.magnitude == rhs.magnitude { return lhs.volume24h > rhs.volume24h }
        return lhs.magnitude > rhs.magnitude
    }
}

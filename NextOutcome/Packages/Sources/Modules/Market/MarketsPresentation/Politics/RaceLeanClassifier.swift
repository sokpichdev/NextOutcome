//
//  RaceLeanClassifier.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import SwiftUI
import MarketsDomain

/// A race's partisan lean bucket, matching the live site's map legend.
public enum RaceLean: Sendable, Equatable, CaseIterable {
    case safeD, likelyD, leanD, tossUp, leanR, likelyR, safeR
    /// No data to classify — either no party-vs-party market was found for this race, or the
    /// state has no race in this chamber this cycle (e.g. only 1/3 of Senate seats are up).
    case noRace

    /// The legend label.
    public var title: String {
        switch self {
        case .safeD: return "Safe D"
        case .likelyD: return "Likely D"
        case .leanD: return "Lean D"
        case .tossUp: return "Toss up"
        case .leanR: return "Lean R"
        case .likelyR: return "Likely R"
        case .safeR: return "Safe R"
        case .noRace: return "No race"
        }
    }

    /// The map fill / legend swatch color, following standard US election-map conventions
    /// (darker = safer, purple = toss-up, gray = no race).
    public var color: Color {
        switch self {
        case .safeD: return Color(red: 0.09, green: 0.24, blue: 0.62)
        case .likelyD: return Color(red: 0.22, green: 0.42, blue: 0.78)
        case .leanD: return Color(red: 0.51, green: 0.65, blue: 0.93)
        case .tossUp: return Color(red: 0.60, green: 0.42, blue: 0.78)
        case .leanR: return Color(red: 0.93, green: 0.56, blue: 0.56)
        case .likelyR: return Color(red: 0.80, green: 0.29, blue: 0.29)
        case .safeR: return Color(red: 0.58, green: 0.11, blue: 0.11)
        case .noRace: return Color(white: 0.35)
        }
    }
}

/// Pure classifier that buckets a race into a `RaceLean` from its Democratic win probability.
public enum RaceLeanClassifier {
    /// Buckets a Democratic win probability into a lean, matching the live site's legend
    /// (>=95% Safe, 80–95% Likely, 60–80% Lean, 40–60% Toss up, mirrored for Republican).
    /// - Parameter democraticProbability: The Democratic candidate/party's win chance (0…1).
    /// - Returns: The corresponding lean bucket.
    public static func lean(democraticProbability p: Decimal) -> RaceLean {
        switch p {
        case let p where p >= 0.95: return .safeD
        case let p where p >= 0.80: return .likelyD
        case let p where p >= 0.60: return .leanD
        case let p where p >= 0.40: return .tossUp
        case let p where p >= 0.20: return .leanR
        case let p where p >= 0.05: return .likelyR
        default: return .safeR
        }
    }

    /// Finds the Democratic party's win probability among a race's candidate markets, when the
    /// race exposes an explicit party-vs-party market. Many races instead list only named
    /// candidates with no party field, in which case there's nothing reliable to classify.
    /// - Parameter markets: The race event's markets.
    /// - Returns: The Democratic party market's Yes price, or `nil` if none is found.
    public static func democraticProbability(in markets: [Market]) -> Decimal? {
        markets.first { ($0.groupItemTitle ?? $0.question).lowercased().contains("democrat") }?.yesOutcome?.price
    }

    /// Classifies a race event's markets directly into a lean bucket — `.noRace` when no
    /// Democratic party market is found.
    /// - Parameter markets: The race event's markets.
    /// - Returns: The race's lean bucket.
    public static func lean(forRaceMarkets markets: [Market]) -> RaceLean {
        guard let probability = democraticProbability(in: markets) else { return .noRace }
        return lean(democraticProbability: probability)
    }
}

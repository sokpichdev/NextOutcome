//
//  ChamberClassifier.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import Foundation

/// Which office a midterms race event is for.
public enum Chamber: String, CaseIterable, Sendable {
    case senate, house, governor
    /// Aggregate/thematic markets under the midterms tag that aren't a single race (e.g.
    /// "Which party will win the Senate in 2026?", "Balance of Power: 2026 Midterms").
    case other

    /// The section title shown above this chamber's races.
    public var title: String {
        switch self {
        case .senate: return "Senate"
        case .house: return "House"
        case .governor: return "Governor"
        case .other: return "Other"
        }
    }
}

/// A race event's resolved chamber and state, or `nil` state when the title didn't match a
/// recognized state name/postal code.
public struct RaceClassification: Equatable, Sendable {
    /// Which office this race is for.
    public let chamber: Chamber
    /// The race's state, as a lowercase postal abbreviation (e.g. "ca"), if resolved.
    public let stateCode: String?

    /// Creates a classification.
    public init(chamber: Chamber, stateCode: String?) {
        self.chamber = chamber
        self.stateCode = stateCode
    }
}

/// Pure classifier that recovers a race's chamber and state from its event title, since Gamma
/// exposes neither as a structured field for these events — only the title.
public enum ChamberClassifier {
    /// House races title their district directly with a postal code, e.g. `"CA-22 House
    /// Election Winner"`. Senate/Governor races spell out the full state name instead, e.g.
    /// `"California Senate Election Winner"` / `"California Governor Election Winner"`.
    private static let housePattern = try! NSRegularExpression(pattern: #"^([A-Za-z]{2})-\d+\s+House Election Winner$"#)
    private static let senatePattern = try! NSRegularExpression(pattern: #"^(.+?)\s+Senate Election Winner$"#)
    private static let governorPattern = try! NSRegularExpression(pattern: #"^(.+?)\s+Governor Election Winner$"#)

    /// Classifies an event title into a chamber and (when resolvable) a state.
    /// - Parameter title: The event's title, as returned by Gamma (may carry incidental
    ///   trailing whitespace, which is trimmed before matching).
    /// - Returns: The resolved chamber/state, or `.other` with a `nil` state for anything that
    ///   isn't a single-race title (aggregate/thematic markets under the same tag).
    public static func classify(title: String) -> RaceClassification {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let range = NSRange(trimmed.startIndex..., in: trimmed)

        if let match = housePattern.firstMatch(in: trimmed, range: range),
           let codeRange = Range(match.range(at: 1), in: trimmed) {
            return RaceClassification(chamber: .house, stateCode: trimmed[codeRange].lowercased())
        }
        if let match = senatePattern.firstMatch(in: trimmed, range: range),
           let nameRange = Range(match.range(at: 1), in: trimmed) {
            return RaceClassification(chamber: .senate, stateCode: USStateGeometry.codesByStateName[trimmed[nameRange].lowercased()])
        }
        if let match = governorPattern.firstMatch(in: trimmed, range: range),
           let nameRange = Range(match.range(at: 1), in: trimmed) {
            return RaceClassification(chamber: .governor, stateCode: USStateGeometry.codesByStateName[trimmed[nameRange].lowercased()])
        }
        return RaceClassification(chamber: .other, stateCode: nil)
    }
}

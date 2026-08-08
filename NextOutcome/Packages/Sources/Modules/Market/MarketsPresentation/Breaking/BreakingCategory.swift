//
//  BreakingCategory.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

/// The category sub-pills shown above the Breaking movers list. Each maps to a Gamma tag id
/// used to scope the `/markets` movers query server-side (`.all` applies no tag filter).
///
/// Tag ids were resolved against `gamma /tags/slug/<slug>`: politics=2, world=101970,
/// sports=1, crypto=21, business(Finance)=107, tech=1401, pop-culture(Culture)=596.
public enum BreakingCategory: String, CaseIterable, Identifiable, Sendable {
    case all, politics, world, sports, crypto, finance, tech, culture

    /// Stable identity for `ForEach`.
    public var id: String { rawValue }

    /// The pill's display label.
    public var title: String {
        switch self {
        case .all:      return "All"
        case .politics: return "Politics"
        case .world:    return "World"
        case .sports:   return "Sports"
        case .crypto:   return "Crypto"
        case .finance:  return "Finance"
        case .tech:     return "Tech"
        case .culture:  return "Culture"
        }
    }

    /// The Gamma tag id this pill scopes the movers query to, or `nil` for "All".
    public var tagID: String? {
        switch self {
        case .all:      return nil
        case .politics: return "2"
        case .world:    return "101970"
        case .sports:   return "1"
        case .crypto:   return "21"
        case .finance:  return "107"
        case .tech:     return "1401"
        case .culture:  return "596"
        }
    }
}

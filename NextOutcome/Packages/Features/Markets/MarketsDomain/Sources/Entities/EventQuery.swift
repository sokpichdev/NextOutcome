//
//  EventQuery.swift
//  NextOutcome
//

/// How to order events when querying a list.
public enum EventSort: Sendable {
    /// By 24-hour trading volume.
    case volume24h
    /// By available liquidity.
    case liquidity
    /// Most recently created first.
    case newest
    /// Closing soonest first.
    case endingSoon
    /// Most competitive (closest to 50/50) first.
    case competitive
}

/// Which events to include by lifecycle status.
public enum EventStatus: Sendable {
    /// Only currently-active (open) events.
    case active
    /// All events, including resolved ones.
    case all
}

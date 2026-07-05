//
//  EventQuery.swift
//  NextOutcome
//

/// How to order events when querying a list.
public enum EventSort: Sendable {
    /// By 24-hour trading volume.
    case volume24h
    /// By 7-day trading volume.
    case volume1wk
    /// By 30-day trading volume.
    case volume1mo
    /// By all-time trading volume.
    case volumeTotal
    /// By available liquidity.
    case liquidity
    /// Most recently created first.
    case newest
    /// Closing soonest first.
    case endingSoon
    /// Most competitive (closest to 50/50) first.
    case competitive
    /// Most recently closed first (resolved events only).
    case closedTime
}

/// Which events to include by lifecycle status.
public enum EventStatus: Sendable {
    /// Only currently-active (open) events.
    case active
    /// Only resolved (closed) events.
    case resolved
    /// All events, regardless of status.
    case all
}

/// How far back an event must have started to be included ("created within").
public enum EventPeriod: Sendable {
    /// Started within the last day.
    case daily
    /// Started within the last week.
    case weekly
    /// Started within the last month.
    case monthly
    /// No start-date restriction.
    case all
}

/// How to order an event's discussion comments.
public enum CommentSort: Sendable {
    /// Most recently posted first.
    case newest
    /// Most-reacted-to first.
    case mostLiked
}

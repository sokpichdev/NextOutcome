//
//  CommentHolding.swift
//  NextOutcome
//

import Foundation

/// One of a commenter's positions in an event, shown as the "holder" badge next to
/// their name (e.g. "1.7K France") and expanded to a full list on tap.
public struct CommentHolding: Identifiable, Hashable, Sendable {
    /// Stable identity (the market's condition id).
    public var id: String { conditionId }
    /// The market's condition id — used to resolve the candidate's display name
    /// (e.g. "France") against the event's markets.
    public let conditionId: String
    /// Which side of the market they hold ("Yes"/"No").
    public let outcome: String
    /// The number of shares held.
    public let size: Decimal

    /// Creates a comment holding.
    public init(conditionId: String, outcome: String, size: Decimal) {
        self.conditionId = conditionId
        self.outcome = outcome
        self.size = size
    }
}

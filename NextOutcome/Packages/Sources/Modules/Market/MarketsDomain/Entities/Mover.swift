//
//  Mover.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import Foundation

/// A single ranked market for the **Breaking** feed — one market whose implied probability
/// moved the most over the last 24 hours. On a mover row the big number is `probability`
/// (the current implied chance) and the coloured delta is `dayChange` (the 24h change in
/// probability, in points): green ▲ when it rose, red ▼ when it fell.
///
/// Movers are individual markets, but the detail screen charts their *sibling* outcomes
/// (e.g. the "July 7/8/9" markets of the same "when will GPT-5.6 release" event), so a mover
/// carries its parent event's `eventSlug`/`eventTitle` to open that grouped chart.
public struct Mover: Identifiable, Hashable {
    /// The market's unique id.
    public let id: String
    /// The market question (e.g. "Will GPT-5.6 be released on July 7, 2026?").
    public let question: String
    /// The parent event's URL slug — used to open the movers detail chart (the sibling
    /// outcomes that share the chart live on the event, not this single market).
    public let eventSlug: String
    /// The parent event's title (e.g. "GPT-5.6 released on…?"), shown in the detail header.
    public let eventTitle: String
    /// The row/detail icon (the parent event's image, falling back to the market's).
    public let imageURL: URL?
    /// The current implied probability (0…1).
    public let probability: Decimal
    /// The 24h change in probability, in points (roughly -1…1). Positive means the chance
    /// rose (green ▲), negative means it fell (red ▼).
    public let dayChange: Decimal
    /// 24h traded volume, used for the ranking tiebreak and the detail's volume line.
    public let volume24h: Decimal

    /// Creates a mover.
    public init(
        id: String,
        question: String,
        eventSlug: String,
        eventTitle: String,
        imageURL: URL?,
        probability: Decimal,
        dayChange: Decimal,
        volume24h: Decimal
    ) {
        self.id = id
        self.question = question
        self.eventSlug = eventSlug
        self.eventTitle = eventTitle
        self.imageURL = imageURL
        self.probability = probability
        self.dayChange = dayChange
        self.volume24h = volume24h
    }

    /// True when the market rose over the last 24h (delta ≥ 0) — drives the green/red arrow.
    public var isUp: Bool { dayChange >= 0 }

    /// The absolute size of the 24h move, used to rank movers by how much they moved
    /// regardless of direction (so the biggest gainers and losers interleave).
    public var magnitude: Decimal { dayChange < 0 ? -dayChange : dayChange }
}

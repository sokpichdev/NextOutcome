//
//  TradeLifecycle.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

/// CLOB trade status flow: `MATCHED → MINED → CONFIRMED`, with `RETRYING`
/// and terminal `FAILED`. Received over the User channel (via the proxy).
public enum TradeLifecycle: String, Sendable, Hashable {
    case matched = "MATCHED"
    case mined = "MINED"
    case confirmed = "CONFIRMED"
    case retrying = "RETRYING"
    case failed = "FAILED"

    public var isTerminal: Bool { self == .confirmed || self == .failed }
}

/// Pure state machine for trade status. Rejects illegal transitions so the UI
/// never shows a fill going backwards.
public enum TradeLifecycleReducer {
    public static func reduce(_ current: TradeLifecycle, _ next: TradeLifecycle) -> TradeLifecycle {
        guard !current.isTerminal else { return current }   // terminal states are sticky
        switch (current, next) {
        case (.matched, .mined),
             (.matched, .retrying),
             (.matched, .failed),
             (.mined, .confirmed),
             (.mined, .retrying),
             (.mined, .failed),
             (.retrying, .mined),
             (.retrying, .confirmed),
             (.retrying, .failed):
            return next
        default:
            return current   // ignore out-of-order / duplicate updates
        }
    }
}

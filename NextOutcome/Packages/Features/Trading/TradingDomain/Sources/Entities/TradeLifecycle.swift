//
//  TradeLifecycle.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

/// CLOB trade status flow: `MATCHED → MINED → CONFIRMED`, with `RETRYING`
/// and terminal `FAILED`. Received over the User channel (via the proxy).
public enum TradeLifecycle: String, Sendable, Hashable {
    /// The order was matched against a counterparty on the order book.
    case matched = "MATCHED"
    /// The matching transaction has been mined into a block on-chain.
    case mined = "MINED"
    /// The trade is fully settled and confirmed. Terminal (success).
    case confirmed = "CONFIRMED"
    /// A transient failure occurred and the trade is being retried.
    case retrying = "RETRYING"
    /// The trade failed and will not complete. Terminal (failure).
    case failed = "FAILED"

    /// Whether this is an end state that can never transition again
    /// (`confirmed` or `failed`). Used to stop applying further updates.
    public var isTerminal: Bool { self == .confirmed || self == .failed }
}

/// Pure state machine for trade status. Rejects illegal transitions so the UI
/// never shows a fill going backwards.
public enum TradeLifecycleReducer {
    /// Applies an incoming status update, returning the new status — or the old one if
    /// the update would be an illegal or out-of-order transition.
    ///
    /// Status arrives over the network and can be duplicated or arrive out of order, so
    /// this guards against regressions: terminal states are sticky, and only the known
    /// forward transitions are allowed.
    /// - Parameters:
    ///   - current: The status shown right now.
    ///   - next: The newly received status update.
    /// - Returns: `next` if the transition is valid, otherwise `current` unchanged.
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

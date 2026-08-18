//
//  PayoutCalculator.swift
//  NextOutcome
//

import Foundation

/// Pure math for every "to win $X" figure in the app. No I/O, no persistence —
/// `SimulatedTradeSubmitter` and the real submitter (Task D) both build on top of this.
///
/// Lives in the shared kernel rather than `TradingDomain` because two slices quote the
/// same payout: the trade sheet's "To win" row, and the crypto live screen's $5/$25/$100
/// tiles. Duplicating the rounding in the second place is how the two come to disagree.
public enum PayoutCalculator {
    /// `shares = amount / price` (price expressed in cents, i.e. 1…99 ⇒ $0.01…$0.99);
    /// `payoutUSD = shares * $1`. Guards divide-by-zero: a zero (or negative) price
    /// yields zero shares/payout rather than crashing or producing `.infinity`/NaN.
    /// Rounds the payout half-even to 2 decimal places.
    public static func potential(amountUSD: Decimal, priceCents: Decimal) -> (shares: Decimal, payoutUSD: Decimal) {
        guard priceCents > 0 else { return (0, 0) }
        let price = priceCents / 100
        let shares = amountUSD / price
        let payout = shares // shares * $1
        var rounded = Decimal()
        var mutablePayout = payout
        NSDecimalRound(&rounded, &mutablePayout, 2, .bankers)
        return (shares, rounded)
    }
}

//
//  TradeSheetViewModel.swift
//  NextOutcome
//

import Foundation
import MarketsDomain
import TradingDomain

/// What the user tapped to open the trade sheet: a market + the side (Yes/No) they
/// picked. `Identifiable` so it can drive a `.sheet(item:)` presentation.
public struct TradeSheetContext: Identifiable {
    /// The market being traded.
    public let market: Market
    /// The side (Yes/No) the user tapped.
    public let side: Side

    /// Creates the context that presents the trade sheet.
    public init(market: Market, side: Side) {
        self.market = market
        self.side = side
    }

    /// A stable identity combining market and side, so `.sheet(item:)` re-presents when
    /// either changes.
    public var id: String { "\(market.id)-\(side)" }
}

/// Drives the mock trade sheet: digit-keypad amount entry, live "to win" payout via
/// `PayoutCalculator`, and a **simulated** submit through the injected `TradeSubmitting`.
/// Confirm is always enabled — nothing here validates balance or persists state; that's
/// the whole point of "mock." Task D swaps the submitter behind the same protocol.
@MainActor
@Observable
public final class TradeSheetViewModel {
    /// The trade sheet's lifecycle: entering an amount, submitting, then success.
    public enum Phase: Equatable {
        /// The user is entering an amount.
        case entering
        /// The (simulated) submit is in flight.
        case submitting
        /// The submit finished.
        case success
    }

    /// The entered amount in cents (whole dollars only, built digit-by-digit).
    public private(set) var amountCents: Int = 0   // dollars entered, digit-by-digit, in cents (no decimals — whole dollars)
    /// The current phase.
    public private(set) var phase: Phase = .entering
    /// The caption shown on the success screen, making the "mock" nature explicit.
    public let successCaption = "Simulated — trading arrives with funding"

    /// The market being traded.
    public let market: Market
    /// The currently-selected side (togglable from within the sheet).
    public private(set) var side: Side
    /// The (simulated) submitter injected from the environment.
    private let submitter: TradeSubmitting

    /// Creates the view model.
    /// - Parameters:
    ///   - market: The market to trade.
    ///   - side: The initial Yes/No side.
    ///   - submitter: The (simulated) trade submitter.
    public init(market: Market, side: Side, submitter: TradeSubmitting) {
        self.market = market
        self.side = side
        self.submitter = submitter
    }

    /// The label for the selected outcome (e.g. "Yes").
    public var outcomeTitle: String {
        switch side {
        case .yes: return market.yesOutcome?.title ?? "Yes"
        case .no: return market.noOutcome?.title ?? "No"
        }
    }

    /// Price in cents (1…99) for the selected side's outcome.
    public var priceCents: Decimal {
        let fraction: Decimal
        switch side {
        case .yes: fraction = market.yesOutcome?.price ?? 0
        case .no: fraction = market.noOutcome?.price ?? 0
        }
        return fraction * 100
    }

    /// The entered amount as dollars.
    public var amountUSD: Decimal {
        Decimal(amountCents) / 100
    }

    /// The entered amount formatted for display (e.g. "$1,234.00").
    public var amountDisplay: String {
        let dollars = amountCents / 100
        let cents = amountCents % 100
        let dollarsFormatted = NumberFormatter.localizedString(from: NSNumber(value: dollars), number: .decimal)
        return String(format: "$%@.%02d", dollarsFormatted, cents)
    }

    /// The shares and "to win" payout for the entered amount, via `PayoutCalculator`.
    public var potential: (shares: Decimal, payoutUSD: Decimal) {
        PayoutCalculator.potential(amountUSD: amountUSD, priceCents: priceCents)
    }

    /// Confirm is always enabled per the design — this is a mock sheet, not a real
    /// order form. Kept as a computed property so the view has a single source of truth.
    public var isConfirmEnabled: Bool { phase == .entering }

    /// Switch the traded side (Yes/No) from inside the sheet. `outcomeTitle`,
    /// `priceCents`, and `potential` all derive from `side`, so the payout updates.
    public func setSide(_ newSide: Side) {
        guard phase == .entering else { return }
        side = newSide
    }

    /// Quick-add a whole-dollar amount from the +$1/+$5/+$10/+$100 chips.
    public func addAmount(_ dollars: Int) {
        guard phase == .entering else { return }
        let next = amountCents + dollars * 100
        guard next <= Self.maxAmountCents else { return }
        amountCents = next
    }

    /// Appends a typed keypad digit, capped at the mock ceiling.
    /// - Parameter digit: The digit (0–9) that was tapped.
    public func appendDigit(_ digit: Int) {
        guard phase == .entering else { return }
        let next = amountCents * 10 + digit
        guard next <= Self.maxAmountCents else { return }
        amountCents = next
    }

    /// Appends two zeroes from the keypad's "00" key, capped at the mock ceiling.
    /// Rejected as a unit rather than digit-by-digit, so a near-ceiling amount doesn't
    /// silently take only one of the two zeroes.
    public func appendDoubleZero() {
        guard phase == .entering else { return }
        let next = amountCents * 100
        guard next <= Self.maxAmountCents else { return }
        amountCents = next
    }

    /// Removes the last entered digit.
    public func backspace() {
        guard phase == .entering else { return }
        amountCents /= 10
    }

    /// Resets the entered amount to zero — the keypad's long-press-on-backspace action.
    public func clear() {
        guard phase == .entering else { return }
        amountCents = 0
    }

    /// A reasonable mock ceiling ($100,000) so keypad entry can't scroll the amount
    /// off-screen.
    private static let maxAmountCents = 100_000_00

    /// Runs the simulated submit: flips to `.submitting`, calls the submitter (ignoring
    /// errors since nothing is real), then flips to `.success`.
    public func confirm() async {
        guard phase == .entering else { return }
        phase = .submitting
        let tradeSide: TradingDomain.TradeSide = (side == .yes) ? .yes : .no
        _ = try? await submitter.submit(
            marketID: market.id,
            side: tradeSide,
            amountUSD: amountUSD,
            priceCents: priceCents
        )
        phase = .success
    }
}

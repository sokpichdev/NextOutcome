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
    public let market: Market
    public let side: Side

    public init(market: Market, side: Side) {
        self.market = market
        self.side = side
    }

    public var id: String { "\(market.id)-\(side)" }
}

/// Drives the mock trade sheet: digit-keypad amount entry, live "to win" payout via
/// `PayoutCalculator`, and a **simulated** submit through the injected `TradeSubmitting`.
/// Confirm is always enabled — nothing here validates balance or persists state; that's
/// the whole point of "mock." Task D swaps the submitter behind the same protocol.
@MainActor
@Observable
public final class TradeSheetViewModel {
    public enum Phase: Equatable {
        case entering
        case submitting
        case success
    }

    public private(set) var amountCents: Int = 0   // dollars entered, digit-by-digit, in cents (no decimals — whole dollars)
    public private(set) var phase: Phase = .entering
    public let successCaption = "Simulated — trading arrives with funding"

    public let market: Market
    public private(set) var side: Side
    private let submitter: TradeSubmitting

    public init(market: Market, side: Side, submitter: TradeSubmitting) {
        self.market = market
        self.side = side
        self.submitter = submitter
    }

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

    public var amountUSD: Decimal {
        Decimal(amountCents) / 100
    }

    public var amountDisplay: String {
        let dollars = amountCents / 100
        let cents = amountCents % 100
        let dollarsFormatted = NumberFormatter.localizedString(from: NSNumber(value: dollars), number: .decimal)
        return String(format: "$%@.%02d", dollarsFormatted, cents)
    }

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
        guard next <= 100_000_00 else { return }
        amountCents = next
    }

    public func appendDigit(_ digit: Int) {
        guard phase == .entering else { return }
        // Cap at a reasonable mock ceiling so the keypad can't scroll amounts off-screen.
        let next = amountCents * 10 + digit
        guard next <= 100_000_00 else { return }
        amountCents = amountCents * 10 + digit
    }

    public func backspace() {
        guard phase == .entering else { return }
        amountCents /= 10
    }

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

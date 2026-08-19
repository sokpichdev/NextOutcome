//
//  TradeSheetViewModel.swift
//  NextOutcome
//

import Foundation
import MarketsDomain
import SharedDomain
import TradingDomain

/// What the user tapped to open the trade sheet: a market + the side (Yes/No) they
/// picked. `Identifiable` so it can drive a `.sheet(item:)` presentation.
public struct TradeSheetContext: Identifiable {
    /// The market being traded.
    public let market: Market
    /// The side (Yes/No) the user tapped.
    public let side: Side
    /// A whole-dollar stake the sheet should open already holding, when the tap that
    /// opened it named an amount — the crypto live screen's $5/$25/$100 tiles. `nil`
    /// everywhere the user still has to type one.
    public let initialDollars: Int?

    /// Creates the context that presents the trade sheet.
    public init(market: Market, side: Side, initialDollars: Int? = nil) {
        self.market = market
        self.side = side
        self.initialDollars = initialDollars
    }

    /// A stable identity combining market, side and any preset stake, so `.sheet(item:)`
    /// re-presents when any of them changes — tapping $25 after $5 must reopen the sheet
    /// on the new amount rather than reuse the old one.
    public var id: String { "\(market.id)-\(side)-\(initialDollars.map(String.init) ?? "")" }
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

    /// The entered amount in cents.
    public private(set) var amountCents: Int = 0

    /// Raw input buffer tracking user keypad keystrokes (e.g. "15", "15.", "15.50").
    private var inputString: String = ""

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
    ///   - initialDollars: A whole-dollar stake to open with, when the caller already
    ///     named one (the crypto live screen's amount tiles). It seeds the keypad rather
    ///     than locking it: backspace and further digits work on it as normal.
    public init(market: Market, side: Side, submitter: TradeSubmitting, initialDollars: Int? = nil) {
        self.market = market
        self.side = side
        self.submitter = submitter
        if let initialDollars, initialDollars > 0 {
            let clampedDollars = min(Self.maxAmountCents / 100, max(0, initialDollars))
            amountCents = clampedDollars * 100
            inputString = "\(clampedDollars)"
        }
    }

    /// The selected side's outcome. Read through `binaryOutcomes` so a market whose sides
    /// are team names ("Eternal Fire Academy") or a line ("Over"/"Under") quotes its real
    /// outcome rather than falling through to a nonexistent Yes/No at 0¢.
    private var selectedOutcome: Outcome? {
        guard let sides = market.binaryOutcomes else { return nil }
        switch side {
        case .yes: return sides.first
        case .no: return sides.second
        }
    }

    /// The label for the selected outcome (e.g. "Yes").
    public var outcomeTitle: String {
        if let selectedOutcome { return selectedOutcome.title }
        switch side {
        case .yes: return "Yes"
        case .no: return "No"
        }
    }

    /// Price in cents (1…99) for the selected side's outcome.
    public var priceCents: Decimal {
        (selectedOutcome?.price ?? 0) * 100
    }

    /// The entered amount as dollars.
    public var amountUSD: Decimal {
        Decimal(amountCents) / 100
    }

    /// The entered amount formatted for display (e.g. "$1.00", "$15.50", "$15.").
    public var amountDisplay: String {
        if inputString.isEmpty {
            return "$0.00"
        }
        if inputString.hasSuffix(".") {
            let parts = inputString.split(separator: ".", omittingEmptySubsequences: false)
            let dollars = Int(parts[0]) ?? 0
            let dollarsFormatted = NumberFormatter.localizedString(from: NSNumber(value: dollars), number: .decimal)
            return "$\(dollarsFormatted)."
        }
        if inputString.contains(".") {
            let parts = inputString.split(separator: ".", omittingEmptySubsequences: false)
            let dollars = Int(parts[0]) ?? 0
            let dollarsFormatted = NumberFormatter.localizedString(from: NSNumber(value: dollars), number: .decimal)
            let dec = String(parts[1])
            if dec.count == 1 {
                return "$\(dollarsFormatted).\(dec)0"
            } else {
                return "$\(dollarsFormatted).\(dec)"
            }
        }
        let dollars = Int(inputString) ?? 0
        let dollarsFormatted = NumberFormatter.localizedString(from: NSNumber(value: dollars), number: .decimal)
        return "$\(dollarsFormatted).00"
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
        if amountCents % 100 == 0 {
            inputString = "\(amountCents / 100)"
        } else {
            inputString = String(format: "%d.%02d", amountCents / 100, amountCents % 100)
        }
    }

    /// Appends a typed keypad digit, capped at the mock ceiling.
    /// Inputting "1" produces $1.00 (whole dollars first).
    /// - Parameter digit: The digit (0–9) that was tapped.
    public func appendDigit(_ digit: Int) {
        guard phase == .entering else { return }
        if inputString.contains(".") {
            let parts = inputString.split(separator: ".", omittingEmptySubsequences: false)
            if parts.count > 1 && parts[1].count >= 2 {
                // Already at maximum 2 decimal places (cents)
                return
            }
            let nextString = inputString + "\(digit)"
            guard let nextCents = parseCents(nextString), nextCents <= Self.maxAmountCents else { return }
            inputString = nextString
            amountCents = nextCents
        } else {
            let nextString = (inputString == "0") ? "\(digit)" : (inputString + "\(digit)")
            guard let nextCents = parseCents(nextString), nextCents <= Self.maxAmountCents else { return }
            inputString = nextString
            amountCents = nextCents
        }
    }

    /// Appends a decimal point from the keypad's "." key.
    public func appendDecimal() {
        guard phase == .entering else { return }
        if inputString.isEmpty {
            inputString = "0."
            amountCents = 0
        } else if !inputString.contains(".") {
            inputString += "."
        }
    }

    /// Removes the last entered digit or decimal separator.
    public func backspace() {
        guard phase == .entering else { return }
        guard !inputString.isEmpty else { return }
        inputString.removeLast()
        amountCents = parseCents(inputString) ?? 0
    }

    /// Resets the entered amount to zero — the keypad's long-press-on-backspace action.
    public func clear() {
        guard phase == .entering else { return }
        inputString = ""
        amountCents = 0
    }

    /// Parses a raw input string like "15", "15.", or "15.50" into total cents.
    private func parseCents(_ s: String) -> Int? {
        if s.isEmpty { return 0 }
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard let dollars = Int(parts[0]) else { return nil }
        var cents = 0
        if parts.count > 1 && !parts[1].isEmpty {
            let dec = String(parts[1])
            if dec.count == 1 {
                cents = (Int(dec) ?? 0) * 10
            } else if dec.count >= 2 {
                cents = Int(dec.prefix(2)) ?? 0
            }
        }
        return dollars * 100 + cents
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

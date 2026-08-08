//
//  BTCLiveSections.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/08/2026.
//

import SwiftUI
import OrderbookDomain
import DesignSystem

/// The non-chart sections of `BTCLiveView`, each its own `View` struct.
///
/// This split is a performance fix, not cosmetics. `@Observable` tracks reads per view
/// body, so while the header, the quick-bet buttons and the trades ticker all lived in
/// `BTCLiveView.body`, a change to *any* of their properties re-ran the whole body —
/// including the `Chart` builder. The countdown alone invalidated the candle chart once a
/// second, and the order book did it on every socket frame. Each section now reads only
/// its own properties, inside its own tracking scope, so the chart is invalidated by
/// candle data and nothing else.

// MARK: - Header

/// The header: the countdown on the left (red when urgent), and the dollar price-to-beat +
/// current price on the right (with a coloured delta, matching web).
///
/// Reads `countdown`, `isCountdownUrgent`, `settlement`, `priceToBeat`, `currentPrice`,
/// `priceDelta` — the 1 Hz properties, kept away from the chart.
struct BTCLiveHeaderSection: View {
    let viewModel: BTCLiveViewModel

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: DSLayout.spacingXSmall) {
                Text(viewModel.hasSettled ? "Window closed" : "Time remaining")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                if let settlement = viewModel.settlement {
                    settlementLabel(settlement)
                } else {
                    Text(viewModel.countdown)
                        .font(DSFont.price)
                        .foregroundStyle(viewModel.isCountdownUrgent ? DSColor.negative : DSColor.textPrimary)
                }
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: DSLayout.spacing) {
                if let target = viewModel.priceToBeat {
                    VStack(alignment: .trailing, spacing: DSLayout.spacingXSmall) {
                        Text("Price to beat")
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                        Text(LiveFormat.usd(target))
                            .font(DSFont.priceSmall)
                            .foregroundStyle(DSColor.textPrimary)
                    }
                }
                if let current = viewModel.currentPrice {
                    VStack(alignment: .trailing, spacing: DSLayout.spacingXSmall) {
                        HStack(spacing: 4) {
                            Text("Current Price")
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.textSecondary)
                            if let delta = viewModel.priceDelta {
                                Text(LiveFormat.delta(delta))
                                    .font(DSFont.caption)
                                    .foregroundStyle(delta >= 0 ? DSColor.positive : DSColor.negative)
                            }
                        }
                        Text(LiveFormat.usd(current))
                            .font(DSFont.priceSmall)
                            .foregroundStyle(DSColor.textPrimary)
                    }
                }
            }
        }
    }

    /// The settled result in place of the countdown: which side the window finished on.
    @ViewBuilder
    private func settlementLabel(_ settlement: BTCLiveViewModel.Settlement) -> some View {
        switch settlement {
        case .up:
            Text("Up won").font(DSFont.price).foregroundStyle(DSColor.positive)
        case .down:
            Text("Down won").font(DSFont.price).foregroundStyle(DSColor.negative)
        case .undetermined:
            Text("Settled").font(DSFont.price).foregroundStyle(DSColor.textSecondary)
        }
    }
}

// MARK: - Quick bet

/// The Up/Down quick-bet buttons showing the current live cents for each side.
///
/// Replaced once the window closes: a closed window's book empties out, so the buttons
/// would read "--" and do nothing — which is exactly what made the ended screen look
/// broken. The whole screen intentionally stays put on the window the user opened, showing
/// how it finished, with one tap to move on.
///
/// Reads `book` (via `upCents`/`downCents`), which ticks on every socket frame.
struct BTCLiveQuickBetSection: View {
    let viewModel: BTCLiveViewModel
    /// Moves the user on once this window has closed; `nil` leaves a dead end with a label.
    let onNextWindow: (() -> Void)?

    var body: some View {
        if viewModel.hasSettled {
            Button(action: { onNextWindow?() }) {
                Text(onNextWindow == nil ? "This window has closed" : "Next window →")
                    .font(DSFont.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DSLayout.spacingMedium)
            }
            .buttonStyle(.plain)
            .foregroundStyle(onNextWindow == nil ? DSColor.textSecondary : DSColor.accent)
            .background(DSColor.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))
            .disabled(onNextWindow == nil)
        } else {
            HStack(spacing: DSLayout.spacing) {
                PriceButton(
                    title: "Up",
                    price: LiveFormat.centsButton(viewModel.upCents),
                    style: .yes
                ) { viewModel.quickBet(.up) }
                PriceButton(
                    title: "Down",
                    price: LiveFormat.centsButton(viewModel.downCents),
                    style: .no
                ) { viewModel.quickBet(.down) }
            }
        }
    }
}

// MARK: - Recent trades

/// The recent-trades list (up to 8 rows), hidden entirely when there are no trades.
/// Reads `recentTrades`, refreshed by a 5-second poll.
struct BTCLiveTradesTicker: View {
    let viewModel: BTCLiveViewModel

    var body: some View {
        if !viewModel.recentTrades.isEmpty {
            DSCard {
                VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
                    Text("Recent trades")
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)
                    ForEach(viewModel.recentTrades.prefix(8)) { trade in
                        HStack {
                            Text(trade.side == .buy ? "Buy" : "Sell")
                                .font(DSFont.caption)
                                .foregroundStyle(trade.side == .buy ? DSColor.positive : DSColor.negative)
                            Text(trade.outcome)
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.textSecondary)
                            Spacer()
                            Text(LiveFormat.cents(trade.price))
                                .font(DSFont.priceSmall)
                                .foregroundStyle(DSColor.textPrimary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Formatting

/// Display formatting for the BTC live screen. `Decimal` stays domain-side; `Double` and
/// label strings only exist here, shared by `BTCLiveView` and the section views above.
enum LiveFormat {
    /// Clamps a domain `Decimal` price into a 0…1 `Double` for the probability chart's axis.
    static func fraction(_ value: Decimal) -> Double {
        min(1, max(0, NSDecimalNumber(decimal: value).doubleValue))
    }

    /// Converts a dollar `Decimal` to an unclamped `Double` for the spot-price charts.
    static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    /// Formats a 0…1 price as a whole-cent label (e.g. "62¢").
    static func cents(_ value: Decimal) -> String {
        "\(Int((fraction(value) * 100).rounded()))¢"
    }

    /// Formats an optional cents value for a quick-bet button, showing "--" when unknown.
    static func centsButton(_ cents: Int?) -> String {
        cents.map { "\($0)¢" } ?? "--"
    }

    /// Formats a dollar `Decimal` as USD (e.g. "$63,945.94").
    static func usd(_ value: Decimal) -> String {
        usdFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "$--"
    }

    /// Formats a signed dollar delta with an arrow (e.g. "▲$15", "▼$8").
    static func delta(_ value: Decimal) -> String {
        let magnitude = usd(abs(value))
        return value >= 0 ? "▲\(magnitude)" : "▼\(magnitude)"
    }

    /// A compact y-axis price label — grouped thousands, no currency symbol or cents, so it
    /// fits a fixed-width axis gutter at every band this chart will ever show.
    static func axis(_ value: Double?) -> String {
        guard let value else { return "" }
        return axisFormatter.string(from: NSNumber(value: value)) ?? ""
    }

    /// A shared USD currency formatter for `usd`/`delta`.
    private static let usdFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()

    /// A shared grouped-decimal formatter for `axis`.
    private static let axisFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

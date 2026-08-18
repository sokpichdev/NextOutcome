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

/// The header, following the web's layout: the market's icon, name and window range on the
/// left with the countdown split into MIN/SECS blocks on the right, then the dollar
/// price-to-beat and current price (with a coloured delta) on the row below.
///
/// Reads `countdownUnits`, `isCountdownUrgent`, `settlement`, `priceToBeat`,
/// `currentPrice`, `priceDelta` — the 1 Hz properties, kept away from the chart.
struct BTCLiveHeaderSection: View {
    let viewModel: BTCLiveViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            identityRow
            Divider().overlay(DSColor.separator)
            priceRow
        }
    }

    // MARK: Identity + countdown

    /// Icon, market name and window range, with the countdown blocks trailing.
    private var identityRow: some View {
        HStack(alignment: .center, spacing: DSLayout.spacingSmall) {
            if let iconURL = viewModel.iconURL {
                AsyncImage(url: iconURL) { $0.resizable().scaledToFill() } placeholder: { DSColor.surfaceElevated }
                    .frame(width: Self.iconSize, height: Self.iconSize)
                    .clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.title)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(viewModel.windowRange)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: DSLayout.spacingSmall)
            if let settlement = viewModel.settlement {
                settlementLabel(settlement)
            } else {
                countdownBlocks
            }
        }
    }

    /// The coin icon's diameter — sized to the two-line title block beside it.
    private static let iconSize: CGFloat = 40

    /// The countdown as the web renders it: two stacked value/unit blocks rather than one
    /// `1:33` string, turning red under a minute.
    private var countdownBlocks: some View {
        HStack(alignment: .top, spacing: DSLayout.spacingSmall) {
            ForEach(viewModel.countdownUnits, id: \.label) { unit in
                VStack(spacing: 0) {
                    Text(unit.value)
                        .font(DSFont.price)
                        .monospacedDigit()
                        .foregroundStyle(viewModel.isCountdownUrgent ? DSColor.negative : DSColor.textPrimary)
                    Text(unit.label)
                        .font(DSFont.caption2)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
        // One roll for the pair: the blocks are two halves of a single value, and rolling
        // them off separate triggers desynchronises the minute from the second it turns on.
        .rollingCountdown(viewModel.remainingSeconds)
    }

    // MARK: Prices

    /// Price to beat and current price, split into web's two columns.
    private var priceRow: some View {
        HStack(alignment: .top, spacing: DSLayout.spacing) {
            if let target = viewModel.priceToBeat {
                VStack(alignment: .leading, spacing: DSLayout.spacingXSmall) {
                    Text("Price To Beat")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                    Text(LiveFormat.usd(target))
                        .font(DSFont.price)
                        .foregroundStyle(DSColor.textPrimary)
                        // The window's open, re-polled every 5s rather than streamed,
                        // so it gets the ordinary roll.
                        .rollingNumber(target)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let current = viewModel.currentPrice {
                VStack(alignment: .leading, spacing: DSLayout.spacingXSmall) {
                    HStack(spacing: 4) {
                        Text("Current Price")
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                        if let delta = viewModel.priceDelta {
                            Text(LiveFormat.delta(delta))
                                .font(DSFont.caption)
                                .foregroundStyle(delta >= 0 ? DSColor.positive : DSColor.negative)
                                .rollingNumber(delta, animation: DSAnimation.liveNumber)
                        }
                    }
                    // Socket-fed: several ticks a second, so it takes the fast roll.
                    Text(LiveFormat.usd(current))
                        .font(DSFont.price)
                        .foregroundStyle(currentPriceColor)
                        .rollingNumber(current, animation: DSAnimation.liveNumber)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// The live price's colour: green while it's at or above the window's open, red once
    /// it falls below — the same test the chart's price line uses, so the two agree on who
    /// is currently winning.
    private var currentPriceColor: Color {
        guard let current = viewModel.currentPrice, let target = viewModel.priceToBeat else {
            return DSColor.textPrimary
        }
        return current >= target ? DSColor.positive : DSColor.negative
    }

    /// The settled result in place of the countdown: which side the window finished on.
    @ViewBuilder
    private func settlementLabel(_ settlement: BTCLiveViewModel.Settlement) -> some View {
        switch settlement {
        case .up:
            Text("Up won").font(DSFont.headline).foregroundStyle(DSColor.positive)
        case .down:
            Text("Down won").font(DSFont.headline).foregroundStyle(DSColor.negative)
        case .undetermined:
            Text("Settled").font(DSFont.headline).foregroundStyle(DSColor.textSecondary)
        }
    }
}

// MARK: - Quick bet

/// The bet controls, following the web: Up/Down pick the side (the picked one fills
/// solid), and the $5/$25/$100 tiles below — each quoting what it would win on that side —
/// are what actually open the trade flow.
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

    /// The stakes the tiles offer, matching the web's own three.
    private static let stakes = [5, 25, 100]

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
            VStack(spacing: DSLayout.spacing) {
                HStack(spacing: DSLayout.spacing) {
                    sideButton(.up, title: "Up", cents: viewModel.upCents, tint: DSColor.positive)
                    sideButton(.down, title: "Down", cents: viewModel.downCents, tint: DSColor.negative)
                }
                HStack(spacing: DSLayout.spacingSmall) {
                    ForEach(Self.stakes, id: \.self) { stake in
                        stakeTile(stake)
                    }
                }
            }
        }
    }

    // MARK: Side selection

    /// One side key. Selected, it fills with its own colour; unselected it drops back to
    /// the neutral surface, so which side the tiles below are quoting is never in doubt.
    /// - Parameters:
    ///   - side: The side this key selects.
    ///   - title: Its label ("Up" / "Down").
    ///   - cents: Its live price, or `nil` before a book arrives.
    ///   - tint: The colour it fills with when selected.
    private func sideButton(
        _ side: BTCLiveViewModel.BetSide,
        title: String,
        cents: Int?,
        tint: Color
    ) -> some View {
        let isSelected = viewModel.selectedSide == side
        return Button { viewModel.select(side) } label: {
            HStack(spacing: DSLayout.spacingXSmall) {
                Text(title).font(DSFont.headline)
                Text(LiveFormat.centsButton(cents))
                    .font(DSFont.headline)
                    .rollingNumber(Double(cents ?? 0), animation: DSAnimation.liveNumber)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(isSelected ? .white : DSColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSLayout.spacing)
        }
        .buttonStyle(
            DSRaisedButtonStyle(
                face: isSelected ? tint : DSColor.surfaceElevated,
                lip: isSelected ? DSLip.tint(tint) : DSLip.surface,
                cornerRadius: DSLayout.cardRadius,
                depth: DSDepth.medium
            )
        )
        .accessibilityLabel("\(title), \(LiveFormat.centsButton(cents))")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: Stakes

    /// One stake tile: the amount, and what it would win on the selected side. Tapping it
    /// opens the trade flow already holding that amount.
    /// - Parameter dollars: The stake this tile bets.
    private func stakeTile(_ dollars: Int) -> some View {
        Button { viewModel.placeBet(dollars: dollars) } label: {
            VStack(spacing: 2) {
                Text("$\(dollars)")
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                // Blank rather than a placeholder before the book lands: the tile still
                // bets, and "win $--" reads as a broken price rather than a pending one.
                Text(winLabel(dollars))
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSLayout.spacingMedium)
        }
        .buttonStyle(
            DSRaisedButtonStyle(
                face: DSColor.surfaceElevated,
                lip: DSLip.surface,
                cornerRadius: DSLayout.cardRadius,
                depth: DSDepth.small
            )
        )
        .accessibilityLabel("Bet $\(dollars) on \(viewModel.selectedSide == .up ? "Up" : "Down")")
    }

    /// "win $21" for the selected side, or an empty line before a book arrives.
    /// - Parameter dollars: The tile's stake.
    private func winLabel(_ dollars: Int) -> String {
        guard let payout = viewModel.potentialWin(dollars: dollars) else { return " " }
        return "win \(LiveFormat.wholeUSD(payout))"
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

    /// Formats a dollar `Decimal` as whole dollars (e.g. "$21") — the stake tiles' payout,
    /// where cents are noise on a number the user is only sizing up.
    static func wholeUSD(_ value: Decimal) -> String {
        wholeUSDFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "$--"
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

    /// A shared whole-dollar currency formatter for `wholeUSD`.
    private static let wholeUSDFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
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

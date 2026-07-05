//
//  MoverCandidateRow.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// One row of a Breaking movers listing: a candidate/deadline's label, its volume, headline
/// chance, and a Buy Yes/No pair. Tapping the label/volume/chance part pushes that specific
/// candidate's own `MarketDetailView` (same Rules/Comments/Top Holders/Positions/Activity
/// treatment, scoped to that one market); tapping a price button fires `onTrade` directly
/// instead of navigating.
struct MoverCandidateRow: View {
    /// The market this row represents (one candidate/deadline of the parent event).
    let market: Market
    /// The parent event id, threaded into the navigation target.
    let eventID: String
    /// Called with the tapped side when Buy Yes/No is pressed.
    let onTrade: (Side) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            NavigationLink(value: MarketNavigationTarget(market: market, eventID: eventID)) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(DSFont.headline)
                            .foregroundStyle(DSColor.textPrimary)
                        Text("\(MarketFormatting.compactUSD(market.volume)) Vol.")
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                    Spacer()
                    if let yes = market.yesOutcome {
                        Text(MarketFormatting.percent(yes.price))
                            .font(DSFont.title)
                            .foregroundStyle(DSColor.textPrimary)
                    }
                }
            }
            .buttonStyle(.plain)
            tradeRow
        }
        .padding(.vertical, DSLayout.spacingSmall)
    }

    /// The candidate's display label — Gamma already gives these markets a short, display-ready
    /// `groupItemTitle` (a date like "July 6", a country name, or a special case like "Not
    /// released before August"), so it's shown verbatim rather than reformatted.
    private var label: String {
        market.groupItemTitle ?? market.question
    }

    /// Buy Yes / Buy No for this specific candidate's market.
    @ViewBuilder
    private var tradeRow: some View {
        if let yes = market.yesOutcome, let no = market.noOutcome {
            HStack(spacing: DSLayout.spacingSmall) {
                PriceButton(title: "Buy \(yes.title)", price: cents(yes.price), style: .yes) { onTrade(.yes) }
                PriceButton(title: "Buy \(no.title)", price: cents(no.price), style: .no) { onTrade(.no) }
            }
        }
    }

    /// Formats a 0…1 price as a cent label (e.g. "17¢").
    private func cents(_ price: Decimal) -> String {
        MarketFormatting.percent(price).replacingOccurrences(of: "%", with: "¢")
    }
}

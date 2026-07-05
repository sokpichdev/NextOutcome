//
//  DateLadderRow.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// One row of a Breaking movers "date ladder" detail (e.g. "GPT-5.6 released by…?"): the
/// deadline date, that market's volume, its headline chance, and a Buy Yes/No pair. Tapping
/// the date/volume/chance part pushes that specific date's own `MarketDetailView` (same
/// Rules/Comments/Top Holders/Positions/Activity treatment, scoped to that one market);
/// tapping a price button fires `onTrade` directly instead of navigating.
struct DateLadderRow: View {
    /// The market this row represents (one "by \<date\>" deadline).
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
                        Text(dateLabel)
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

    /// The market's end date formatted as "July 6" (no year — the ladder rows are all within
    /// one event, so the year adds no information and just clutters the row).
    private var dateLabel: String {
        guard let endDate = market.endDate else { return market.question }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: endDate)
    }

    /// Buy Yes / Buy No for this specific date's market.
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

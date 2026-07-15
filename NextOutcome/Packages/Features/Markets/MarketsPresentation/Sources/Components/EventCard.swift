//
//  EventCard.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// A card summarizing one event: icon, title, the first market's Yes price + probability
/// bar, and a volume/market-count footer. Used in feed lists.
public struct EventCard: View {
    /// The event to render.
    private let event: Event

    /// Creates the card.
    /// - Parameter event: The event to display.
    public init(event: Event) {
        self.event = event
    }
    
    public var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                HStack(alignment: .top, spacing: DSLayout.spacing) {
                    icon
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(DSFont.headline)
                            .foregroundStyle(DSColor.textPrimary)
                            .lineLimit(2)
                        if let market = event.markets.first,
                           let countdown = MarketFormatting.countdown(to: market.endDate) {
                            Text(countdown)
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let market = event.markets.first, let yes = market.yesOutcome {
                        ChanceGauge(
                            fraction: MarketFormatting.fraction(yes.price),
                            percentText: MarketFormatting.percent(yes.price)
                        )
                    }
                }

                if let market = event.markets.first, let yes = market.yesOutcome, let no = market.noOutcome {
                    HStack(spacing: DSLayout.spacingSmall) {
                        NavigationLink(value: MarketNavigationTarget(market: market, eventID: event.id)) {
                            outcomeLabel(title: "Yes", price: MarketFormatting.centsWhole(yes.price), color: DSColor.positive)
                        }
                        .buttonStyle(
                            DSRaisedButtonStyle(face: DSColor.positiveTint, lip: DSLip.tint(DSColor.positiveTint), depth: DSDepth.medium)
                        )
                        NavigationLink(value: MarketNavigationTarget(market: market, eventID: event.id)) {
                            outcomeLabel(title: "No", price: MarketFormatting.centsWhole(no.price), color: DSColor.negative)
                        }
                        .buttonStyle(
                            DSRaisedButtonStyle(face: DSColor.negativeTint, lip: DSLip.tint(DSColor.negativeTint), depth: DSDepth.medium)
                        )
                    }
                }
                HStack {
                    Text("\(MarketFormatting.compactUSD(event.volume)) vol")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                    Spacer()
                    Text("\(event.markets.count) market\(event.markets.count == 1 ? "" : "s")")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
    }
    
    /// A Yes/No trade button's label — outcome name leading, cent price trailing,
    /// matching `PriceButton`'s default layout so these buttons read as the same
    /// component as every other trade row in the app.
    private func outcomeLabel(title: String, price: String, color: Color) -> some View {
        HStack(spacing: DSLayout.spacingXSmall) {
            Text(title).font(DSFont.subheadline.bold())
            Spacer(minLength: DSLayout.spacingXSmall)
            Text(price).font(DSFont.priceSmall)
        }
        .foregroundStyle(color)
        .padding(.horizontal, DSLayout.spacingMedium)
        .padding(.vertical, DSLayout.spacingSmall)
        .frame(maxWidth: .infinity)
    }

    /// The event icon, loaded async with a placeholder, or a plain rounded rectangle when
    /// there's no image URL.
    @ViewBuilder
    private var icon: some View {
        if let url = event.imageURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                DSColor.surfaceElevated
            }
            .frame(width: DSLayout.iconsize, height: DSLayout.iconsize)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
        } else {
            RoundedRectangle(cornerRadius: DSLayout.chipRadius)
                .fill(DSColor.surfaceElevated)
                .frame(width: DSLayout.iconsize, height: DSLayout.iconsize)
        }
    }
}

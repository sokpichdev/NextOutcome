//
//  MarketCard.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// A card summarizing one market: icon, question, Yes/No price pills, and a volume +
/// countdown footer. Used in feed lists.
public struct MarketCard: View {
    /// The market to render.
    private let market: Market

    /// Creates the card.
    /// - Parameter market: The market to display.
    public init(market: Market) {
        self.market = market
    }

    public var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                HStack(alignment: .top, spacing: DSLayout.spacing) {
                    icon
                    Text(market.question)
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textPrimary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let yes = market.yesOutcome {
                    HStack(spacing: 8) {
                        OutcomePill(.yes, value: MarketFormatting.percent(yes.price))
                        OutcomePill(.no, value: MarketFormatting.percent(yes.complement))
                        Spacer()
                    }
                }

                HStack {
                    Text("\(MarketFormatting.compactUSD(market.volume)) Vol")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                    Spacer()
                    if let countdown = MarketFormatting.countdown(to: market.endDate) {
                        Text(countdown)
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }
            }
        }
    }

    /// The market icon, loaded async with a placeholder, or a plain rounded rectangle when
    /// there's no image URL.
    @ViewBuilder
    private var icon: some View {
        if let url = market.imageURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
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

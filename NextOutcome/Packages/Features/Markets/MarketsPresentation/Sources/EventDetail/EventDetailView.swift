//
//  EventDetailView.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

public struct EventDetailView: View {
    private let event: Event

    public init(event: Event) {
        self.event = event
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                header
                ForEach(event.markets) { market in
                    NavigationLink(value: market) {
                        MarketCard(market: market)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.top, DSLayout.spacing)
        }
        .background(DSColor.background)
        .navigationTitle(event.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var header: some View {
        DSCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.textPrimary)
                Text("\(MarketFormatting.compactUSD(event.volume)) Vol · \(event.markets.count) markets")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
    }
}


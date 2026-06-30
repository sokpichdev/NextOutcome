//
//  DesignSystemGallery.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

#Preview("DesignSystem Gallery") {
    ScrollView {
        VStack(spacing: 20) {
            // Outcome pills
            HStack {
                OutcomePill(.yes, value: "62%")
                OutcomePill(.no, value: "38%")
            }

            // Probability bar
            ProbabilityBar(yesFraction: 0.62)
                .padding(.horizontal)

            // Chips
            HStack {
                DSChip("All", isActive: true) {}
                DSChip("Politics", isActive: false) {}
                DSChip("Crypto", isActive: false) {}
            }

            // Buttons
            Button("Buy Yes · 62%") {}
                .buttonStyle(DSBuyYesButtonStyle())
                .padding(.horizontal)
            Button("Buy No · 38%") {}
                .buttonStyle(DSBuyNoButtonStyle())
                .padding(.horizontal)
            Button("Review Order") {}
                .buttonStyle(DSPrimaryButtonStyle())
                .padding(.horizontal)

            // Badges
            HStack {
                StatusBadge("CONFIRMED", color: DSColor.positive)
                StatusBadge("RESTING", color: DSColor.accent)
                StatusBadge("FAILED", color: DSColor.negative)
            }

            // Value + PnL card with sparkline
            ValuePnLHeader(
                title: "Portfolio value",
                value: "$1,240.55",
                change: "▲ +$84.20 (7.3%) today",
                isPositive: true,
                sparkData: DesignSystemGallery_Previews.sampleData
            )
            .padding(.horizontal)
        }
        .padding()
    }
    .background(DSColor.background)
}

private extension DesignSystemGallery_Previews {
    static var sampleData: [PricePoint] {
        (0..<30).map { i in
            PricePoint(
                date: Date().addingTimeInterval(Double(i) * -3600),
                price: 0.55 + Double.random(in: -0.05...0.1)
            )
        }.reversed()
    }
}

// Required because #Preview can't reference static let inside itself
private enum DesignSystemGallery_Previews {}

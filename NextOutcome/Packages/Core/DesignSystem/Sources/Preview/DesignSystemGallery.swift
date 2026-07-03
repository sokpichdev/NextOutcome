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

#Preview("Shell — Top bar + rail") {
    struct Demo: View {
        @State var category: ShellCategory = .worldCup
        var body: some View {
            VStack(spacing: 0) {
                NOTopBar()
                CategoryRail(selected: $category)
            }
            .background(DSColor.background)
        }
    }
    return Demo()
}

#Preview("Shell — Drawer") {
    SideMenuDrawer(addressShort: "0xd8C7e8F2…", onSelect: { _ in })
        .frame(width: 320)
}

#Preview("Shell — Chrome") {
    struct Demo: View {
        @State var category: ShellCategory = .trending
        var body: some View {
            ShellChrome(selectedCategory: $category, onAvatar: {}) {
                ScrollView { Text("Content").foregroundStyle(DSColor.textPrimary).padding() }
            }
        }
    }
    return Demo()
}

#Preview("Detail — header + chart") {
    VStack(spacing: 16) {
        DetailHeader(title: .breadcrumb("Sports · World Cup"),
                     actions: [.bookmark, .link], onBack: {})
        DetailHeader(title: .text("France", iconURL: nil),
                     actions: [.code, .bookmark, .link], onBack: {})
        MultiSeriesChart(series: [
            PriceSeries(id: "fr", label: "France", color: DSColor.accent,
                        points: (0..<8).map { PricePoint(date: Date().addingTimeInterval(Double($0) * 3600), price: 0.2 + Double($0) * 0.02) }),
            PriceSeries(id: "ar", label: "Argentina", color: DSColor.positive,
                        points: (0..<8).map { PricePoint(date: Date().addingTimeInterval(Double($0) * 3600), price: 0.18 - Double($0) * 0.005) })
        ]).frame(height: 200)
    }
    .padding()
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

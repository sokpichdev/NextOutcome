//
//  DesignSystemGallery.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

/// This file contains only Xcode Preview canvases (`#Preview` blocks) — no
/// production code. It exists purely so developers can visually browse every
/// `DesignSystem` component in one place (Xcode's canvas/preview panel) without
/// running the full app, which is especially useful while tweaking colors,
/// fonts, or spacing tokens. Each `#Preview` below demonstrates a different
/// group of components: core building blocks (pills, bars, chips, buttons,
/// badges, the value/PnL header), the persistent shell chrome (top bar,
/// category rail, side drawer), and a detail-page header + multi-series chart.

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
        @State var category: HubTab = .worldCup
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

#Preview("Shell — Drawer (Dark)") {
    SideMenuDrawer(addressShort: "0xd8C7e8F2…", isDarkMode: true, onSelect: { _ in })
        .frame(width: 320)
}

#Preview("Shell — Drawer (Light)") {
    SideMenuDrawer(addressShort: "0xd8C7e8F2…", isDarkMode: false, onSelect: { _ in })
        .frame(width: 320)
        .preferredColorScheme(.light)
}

#Preview("Shell — Chrome") {
    struct Demo: View {
        @State var category: HubTab = .trending
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
    /// Generates 30 hours of randomized-but-plausible price points (centered
    /// around 55¢) purely for feeding the `ValuePnLHeader` sparkline preview above.
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
/// An empty marker type — exists solely so `sampleData` above has a namespace
/// to live in, since Swift's `#Preview` macro can't directly reference a
/// standalone top-level `static let`.
private enum DesignSystemGallery_Previews {}

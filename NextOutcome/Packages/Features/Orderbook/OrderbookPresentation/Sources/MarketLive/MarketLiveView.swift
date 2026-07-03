//
//  MarketLiveView.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import OrderbookDomain
import DesignSystem

/// Price-history section embedded in the Market Detail screen. The order book itself
/// is `OrderbookView` (expandable, live-updating) rendered separately below this.
public struct MarketLiveView: View {
    @State private var viewModel: MarketLiveViewModel

    public init(viewModel: MarketLiveViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        chartSection
            .onAppear { viewModel.start() }
            .onDisappear { viewModel.stop() }
    }

    // MARK: Chart

    private var chartSection: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                HStack {
                    Text("Price")
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)
                    Spacer()
                    connectionBadge
                }
                if viewModel.history.isEmpty {
                    Text("No price history")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                        .frame(height: 160)
                        .frame(maxWidth: .infinity)
                } else {
                    PriceChart(data: viewModel.history.map {
                        PricePoint(date: $0.date, price: fractionValue($0.price))
                    })
                    .frame(height: 160)
                }
                intervalPicker
            }
        }
    }

    private var intervalPicker: some View {
        HStack(spacing: 8) {
            ForEach(PriceHistoryInterval.allCases, id: \.self) { option in
                DSChip(option.rawValue.uppercased(), isActive: viewModel.interval == option) {
                    viewModel.interval = option
                }
            }
        }
    }

    private var connectionBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
            Text(connectionLabel)
                .font(DSFont.caption2)
                .foregroundStyle(DSColor.textSecondary)
        }
    }

    private var connectionColor: Color {
        switch viewModel.connection {
        case .live: return DSColor.positive
        case .connecting: return DSColor.textSecondary
        case .offline: return DSColor.negative
        }
    }

    private var connectionLabel: String {
        switch viewModel.connection {
        case .live: return "Live"
        case .connecting: return "Connecting…"
        case .offline: return "Offline"
        }
    }

    // MARK: Formatting (Decimal stays domain-side; Double only here)

    private func fractionValue(_ value: Decimal) -> Double {
        min(1, max(0, NSDecimalNumber(decimal: value).doubleValue))
    }
}

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
    /// The view model driving the chart and connection status.
    @State private var viewModel: MarketLiveViewModel

    /// Creates the view.
    /// - Parameter viewModel: The live-market view model (usually from `marketLiveFactory`).
    public init(viewModel: MarketLiveViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        chartSection
            .onAppear { viewModel.start() }
            .onDisappear { viewModel.stop() }
    }

    // MARK: Chart

    /// The chart card: title, connection badge, the price chart (or an empty state), and
    /// the interval picker.
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

    /// The row of chips that let the user switch the chart's time window.
    private var intervalPicker: some View {
        HStack(spacing: 8) {
            ForEach(PriceHistoryInterval.allCases, id: \.self) { option in
                DSChip(option.rawValue.uppercased(), isActive: viewModel.interval == option) {
                    viewModel.interval = option
                }
            }
        }
    }

    /// A small coloured dot + label showing the live/connecting/offline status.
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

    /// The dot colour for the current connection status.
    private var connectionColor: Color {
        switch viewModel.connection {
        case .live: return DSColor.positive
        case .connecting: return DSColor.textSecondary
        case .offline: return DSColor.negative
        }
    }

    /// The text label for the current connection status.
    private var connectionLabel: String {
        switch viewModel.connection {
        case .live: return "Live"
        case .connecting: return "Connecting…"
        case .offline: return "Offline"
        }
    }

    // MARK: Formatting (Decimal stays domain-side; Double only here)

    /// Converts a domain `Decimal` price into a clamped 0…1 `Double` for the chart, keeping
    /// `Decimal` on the domain side and only crossing to `Double` at the view boundary.
    private func fractionValue(_ value: Decimal) -> Double {
        min(1, max(0, NSDecimalNumber(decimal: value).doubleValue))
    }
}

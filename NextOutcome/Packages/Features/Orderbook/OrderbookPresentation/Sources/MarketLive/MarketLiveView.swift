//
//  MarketLiveView.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import OrderbookDomain
import DesignSystem

/// Live orderbook + price-history section embedded in the Market Detail screen.
public struct MarketLiveView: View {
    @State private var viewModel: MarketLiveViewModel

    public init(viewModel: MarketLiveViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingLarge) {
            chartSection
            bookSection
        }
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

    // MARK: Order book

    @ViewBuilder
    private var bookSection: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                HStack {
                    Text("Order book")
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)
                    Spacer()
                    if let spread = viewModel.book?.spread {
                        Text("Spread \(cents(spread))")
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }
                if let book = viewModel.book, !book.isEmpty {
                    OrderbookDepthView(
                        bids: depthLevels(book.bids),
                        asks: depthLevels(book.asks)
                    )
                } else {
                    Text("Waiting for book…")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, DSLayout.spacing)
                }
            }
        }
    }

    private func depthLevels(_ levels: [PriceLevel], limit: Int = 8) -> [DepthLevel] {
        let shown = Array(levels.prefix(limit))
        let maxSize = shown.map(\.size).max() ?? 1
        return shown.map { level in
            DepthLevel(
                price: cents(level.price),
                size: compact(level.size),
                fraction: fractionValue(maxSize == 0 ? 0 : level.size / maxSize)
            )
        }
    }

    // MARK: Formatting (Decimal stays domain-side; Double only here)

    private func fractionValue(_ value: Decimal) -> Double {
        min(1, max(0, NSDecimalNumber(decimal: value).doubleValue))
    }

    private func cents(_ price: Decimal) -> String {
        let value = NSDecimalNumber(decimal: price * 100).doubleValue
        return String(format: "%.1f¢", value)
    }

    private func compact(_ size: Decimal) -> String {
        let value = NSDecimalNumber(decimal: size).doubleValue
        switch value {
        case 1_000_000...: return String(format: "%.1fM", value / 1_000_000)
        case 1_000...: return String(format: "%.1fK", value / 1_000)
        default: return String(Int(value.rounded()))
        }
    }
}

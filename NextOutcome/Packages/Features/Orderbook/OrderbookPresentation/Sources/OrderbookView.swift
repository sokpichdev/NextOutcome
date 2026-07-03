//
//  OrderbookView.swift
//  NextOutcome
//

import SwiftUI
import OrderbookDomain
import DesignSystem
import SharedDomain

/// Expandable live order book: collapsed shows the top 3 levels per side + a spread
/// row + "Show more"; expanded shows 10. Green bid / red ask depth bars scale with
/// each level's cumulative size (deepest levels read as "wider"), via `OrderbookDepthView`.
public struct OrderbookView: View {
    @State private var viewModel: OrderbookViewModel

    private static let collapsedRowCount = 3
    private static let expandedRowCount = 10

    public init(viewModel: OrderbookViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                header
                content
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var header: some View {
        HStack {
            Text("Order book")
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
            Spacer()
            connectionPill
        }
    }

    @ViewBuilder
    private var connectionPill: some View {
        switch viewModel.connection {
        case .live:
            EmptyView()
        case .connecting:
            StatusBadge("Connecting…", color: DSColor.textSecondary)
        case .reconnecting:
            StatusBadge("Reconnecting…", color: DSColor.negative)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .tint(DSColor.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSLayout.spacingLarge)
        case .empty:
            Text("No open orders on this book yet.")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, DSLayout.spacing)
        case .failed(let message):
            retryRow(message)
        case .loaded(let ladder):
            ladderContent(ladder)
        }
    }

    private func retryRow(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            Text(message)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
            Button("Retry") { Task { await viewModel.retry() } }
                .font(DSFont.caption.bold())
                .foregroundStyle(DSColor.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DSLayout.spacing)
    }

    @ViewBuilder
    private func ladderContent(_ ladder: BookLadder) -> some View {
        let rows = viewModel.expanded ? Self.expandedRowCount : Self.collapsedRowCount
        if ladder.bids.isEmpty && ladder.asks.isEmpty {
            Text("Waiting for book…")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, DSLayout.spacing)
        } else {
            OrderbookDepthView(
                bids: depthLevels(ladder.bids, limit: rows),
                asks: depthLevels(ladder.asks, limit: rows)
            )
            spreadRow(ladder)
            showMoreButton
        }
    }

    private func spreadRow(_ ladder: BookLadder) -> some View {
        HStack {
            Spacer()
            Text("Spread \(String(format: "%.1f¢", NSDecimalNumber(decimal: ladder.spreadCents).doubleValue))")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
            Spacer()
        }
    }

    private var showMoreButton: some View {
        Button(viewModel.expanded ? "Show less" : "Show more") {
            viewModel.toggleExpanded()
        }
        .font(DSFont.caption.bold())
        .foregroundStyle(DSColor.accent)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: Formatting (Decimal stays domain-side; Double only here)

    private func depthLevels(_ levels: [BookLadder.Level], limit: Int) -> [DepthLevel] {
        let shown = Array(levels.prefix(limit))
        let maxCumulative = shown.map(\.cumulative).max() ?? 1
        return shown.map { level in
            DepthLevel(
                price: cents(level.price),
                size: compact(level.size),
                fraction: fraction(level.cumulative, of: maxCumulative)
            )
        }
    }

    private func fraction(_ value: Decimal, of maxValue: Decimal) -> Double {
        guard maxValue > 0 else { return 0 }
        return Swift.min(1, Swift.max(0, NSDecimalNumber(decimal: value / maxValue).doubleValue))
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

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
    /// The view model driving the book. Held in `@State` so it survives view redraws.
    @State private var viewModel: OrderbookViewModel

    /// How many levels per side to show when collapsed.
    private static let collapsedRowCount = 3
    /// How many levels per side to show when expanded.
    private static let expandedRowCount = 10

    /// Creates the view.
    /// - Parameter viewModel: The order book view model (usually from `orderbookFactory`).
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

    /// The card header: the "Order book" title and a connection status pill.
    private var header: some View {
        HStack {
            Text("Order book")
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
            Spacer()
            connectionPill
        }
    }

    /// The status pill: hidden when live, otherwise shows connecting/reconnecting.
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

    /// The main body, switching on the view model's load state (loading / empty / failed /
    /// loaded ladder).
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

    /// An error message with a retry button, shown when the initial load fails.
    /// - Parameter message: The error text to show.
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

    /// Renders the depth bars, spread row, and show-more toggle for a loaded ladder,
    /// limiting rows to the collapsed/expanded count.
    /// - Parameter ladder: The ladder to render.
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

    /// The centered "Spread X¢" row between the two sides of the book.
    /// - Parameter ladder: The ladder whose spread to show.
    private func spreadRow(_ ladder: BookLadder) -> some View {
        HStack {
            Spacer()
            Text("Spread \(String(format: "%.1f¢", NSDecimalNumber(decimal: ladder.spreadCents).doubleValue))")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
            Spacer()
        }
    }

    /// The "Show more"/"Show less" toggle that expands/collapses the book.
    private var showMoreButton: some View {
        Button(viewModel.expanded ? "Show less" : "Show more") {
            viewModel.toggleExpanded()
        }
        .font(DSFont.caption.bold())
        .foregroundStyle(DSColor.accent)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: Formatting (Decimal stays domain-side; Double only here)

    /// Converts domain ladder levels into the view's `DepthLevel`s, formatting the price and
    /// size as strings and normalizing each level's cumulative size to a 0…1 bar fraction.
    /// - Parameters:
    ///   - levels: The ladder levels for one side.
    ///   - limit: The maximum number of levels to show.
    /// - Returns: Presentation-ready depth levels.
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

    /// Normalizes a value to a 0…1 fraction of a maximum, for the depth bar width.
    private func fraction(_ value: Decimal, of maxValue: Decimal) -> Double {
        guard maxValue > 0 else { return 0 }
        return Swift.min(1, Swift.max(0, NSDecimalNumber(decimal: value / maxValue).doubleValue))
    }

    /// Formats a 0…1 price as a cent string (e.g. "62.0¢").
    private func cents(_ price: Decimal) -> String {
        let value = NSDecimalNumber(decimal: price * 100).doubleValue
        return String(format: "%.1f¢", value)
    }

    /// Formats a size compactly with K/M suffixes (e.g. "12.3K").
    private func compact(_ size: Decimal) -> String {
        let value = NSDecimalNumber(decimal: size).doubleValue
        switch value {
        case 1_000_000...: return String(format: "%.1fM", value / 1_000_000)
        case 1_000...: return String(format: "%.1fK", value / 1_000)
        default: return String(Int(value.rounded()))
        }
    }
}

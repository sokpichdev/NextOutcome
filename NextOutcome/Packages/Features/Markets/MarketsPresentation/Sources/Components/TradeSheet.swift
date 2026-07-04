//
//  TradeSheet.swift
//  NextOutcome
//

import SwiftUI
import DesignSystem
import MarketsDomain
import TradingDomain

/// Mock trade entry sheet: outcome + side pill, a big dollar amount driven by a digit
/// keypad, a "To win $X" row from `PayoutCalculator`, and a Confirm button that always
/// succeeds — this is a **simulated** trade. No order is sent and nothing persists;
/// Confirm plays a short success animation with `successCaption`, then auto-dismisses.
public struct TradeSheet: View {
    /// Dismisses the sheet (used after the success animation).
    @Environment(\.dismiss) private var dismiss
    /// The view model driving amount entry, side, payout, and submission.
    @State private var viewModel: TradeSheetViewModel

    /// Creates the sheet.
    /// - Parameter viewModel: The trade-sheet view model.
    public init(viewModel: TradeSheetViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: DSLayout.spacingLarge) {
            header
            if viewModel.phase == .success {
                successView
            } else {
                amountBlock
                sideToggle
                quickAmountRow
                toWinRow
                confirmButton
                keypad
            }
        }
        .padding(DSLayout.margin)
        .background(DSColor.background)
        .onChange(of: viewModel.phase) { _, new in
            guard new == .success else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                dismiss()
            }
        }
    }

    /// The sheet header: market icon plus the market title and selected-outcome subtitle.
    private var header: some View {
        HStack(spacing: DSLayout.spacingSmall) {
            CardIcon(url: viewModel.market.imageURL)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.market.groupItemTitle ?? viewModel.market.question)
                    .font(DSFont.subheadline.bold())
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Text("\(viewModel.market.groupItemTitle ?? viewModel.market.question) · \(viewModel.outcomeTitle)")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    /// Segmented Yes/No control — switches the traded side in place, updating the
    /// payout and subtitle. Selected side takes its green/red tint.
    private var sideToggle: some View {
        HStack(spacing: 0) {
            sideSegment(.yes, title: "Yes", tint: DSColor.positive, fill: DSColor.positiveTint)
            sideSegment(.no, title: "No", tint: DSColor.negative, fill: DSColor.negativeTint)
        }
        .background(DSColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
    }

    /// Builds one Yes/No segment button, tinted when it's the selected side.
    /// - Parameters:
    ///   - side: The side this segment selects.
    ///   - title: The button label.
    ///   - tint: The text/foreground colour when selected.
    ///   - fill: The background fill when selected.
    private func sideSegment(_ side: Side, title: String, tint: Color, fill: Color) -> some View {
        let selected = viewModel.side == side
        return Button {
            viewModel.setSide(side)
        } label: {
            Text(title)
                .font(DSFont.subheadline.bold())
                .foregroundStyle(selected ? tint : DSColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSLayout.spacingSmall)
                .background(selected ? fill : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
        }
        .buttonStyle(.plain)
    }

    /// The +$1/+$5/+$10/+$100 quick-add chips.
    private var quickAmountRow: some View {
        HStack(spacing: DSLayout.spacingSmall) {
            ForEach([1, 5, 10, 100], id: \.self) { amount in
                Button {
                    viewModel.addAmount(amount)
                } label: {
                    Text("+$\(amount)")
                        .font(DSFont.subheadline.bold())
                        .foregroundStyle(DSColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSLayout.spacingSmall)
                        .background(DSColor.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The large monospaced amount display.
    private var amountBlock: some View {
        Text(viewModel.amountDisplay)
            .font(.system(size: 44, weight: .bold, design: .monospaced))
            .foregroundStyle(DSColor.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSLayout.spacing)
    }

    /// The "To win $X" payout row derived from the entered amount.
    private var toWinRow: some View {
        HStack {
            Text("To win")
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
            Spacer()
            Text(MarketFormatting.compactUSD(viewModel.potential.payoutUSD))
                .font(DSFont.subheadline.bold())
                .foregroundStyle(DSColor.positive)
        }
        .padding(.horizontal, DSLayout.spacingSmall)
    }

    /// The Trade/Confirm button, showing a spinner while submitting.
    private var confirmButton: some View {
        Button {
            Task { await viewModel.confirm() }
        } label: {
            Group {
                if viewModel.phase == .submitting {
                    ProgressView().tint(.white)
                } else {
                    Text("Trade")
                        .font(DSFont.subheadline.bold())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSLayout.spacing)
            .foregroundStyle(.white)
            .background(DSGradient.accent)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isConfirmEnabled)
    }

    /// The custom digit keypad (1–9, 0, and backspace) driving amount entry.
    private var keypad: some View {
        let rows: [[String]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            ["", "0", "⌫"]
        ]
        return VStack(spacing: DSLayout.spacingSmall) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: DSLayout.spacingSmall) {
                    ForEach(row, id: \.self) { key in
                        keypadButton(key)
                    }
                }
            }
        }
    }

    /// Builds one keypad key. An empty string renders a blank spacer; "⌫" deletes; a digit
    /// appends.
    /// - Parameter key: The key label.
    @ViewBuilder
    private func keypadButton(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(maxWidth: .infinity, minHeight: 44)
        } else {
            Button {
                if key == "⌫" {
                    viewModel.backspace()
                } else if let digit = Int(key) {
                    viewModel.appendDigit(digit)
                }
            } label: {
                Text(key)
                    .font(DSFont.title3.bold())
                    .foregroundStyle(DSColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    /// The success state: an animated checkmark and the "simulated" caption.
    private var successView: some View {
        VStack(spacing: DSLayout.spacing) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(DSColor.positive)
                .transition(.scale.combined(with: .opacity))
            Text(viewModel.successCaption)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSLayout.spacingXLarge)
        .animation(.easeOut(duration: 0.25), value: viewModel.phase)
    }
}

#if DEBUG
#Preview("Trade sheet") {
    let market = Market(id: "m1", question: "Will it happen?", slug: "m1",
                         outcomes: [Outcome(id: "y", title: "Yes", price: 0.62),
                                    Outcome(id: "n", title: "No", price: 0.38)],
                         volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil)
    TradeSheet(viewModel: TradeSheetViewModel(market: market, side: .yes, submitter: PreviewSubmitter()))
}

private struct PreviewSubmitter: TradeSubmitting {
    func submit(marketID: String, side: TradingDomain.TradeSide, amountUSD: Decimal, priceCents: Decimal) async throws -> TradeReceipt {
        TradeReceipt(simulated: true, shares: 0)
    }
}
#endif

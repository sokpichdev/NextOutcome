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
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TradeSheetViewModel

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

    private var header: some View {
        HStack(spacing: DSLayout.spacingSmall) {
            Text(viewModel.market.groupItemTitle ?? viewModel.market.question)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .lineLimit(1)
            sidePill
            Spacer()
        }
    }

    private var sidePill: some View {
        Text(viewModel.outcomeTitle)
            .font(DSFont.caption.bold())
            .foregroundStyle(viewModel.side == .yes ? DSColor.positive : DSColor.negative)
            .padding(.horizontal, DSLayout.spacingMedium)
            .padding(.vertical, DSLayout.spacingXSmall)
            .background(viewModel.side == .yes ? DSColor.positiveTint : DSColor.negativeTint)
            .clipShape(Capsule())
    }

    private var amountBlock: some View {
        Text(viewModel.amountDisplay)
            .font(.system(size: 44, weight: .bold, design: .monospaced))
            .foregroundStyle(DSColor.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSLayout.spacing)
    }

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

    private var confirmButton: some View {
        Button {
            Task { await viewModel.confirm() }
        } label: {
            Group {
                if viewModel.phase == .submitting {
                    ProgressView().tint(.white)
                } else {
                    Text("Confirm")
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

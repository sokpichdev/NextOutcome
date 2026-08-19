//
//  TradeSheet.swift
//  NextOutcome
//
//  Created by Sok Pich on 12/8/2026.
//

import SwiftUI
import DesignSystem
import MarketsDomain
import TradingDomain
import TradingPresentation

/// Mock trade entry sheet: a raised Yes/No side picker, a big dollar amount driven by
/// the custom `DSNumberPad`, a "To win $X" row from `PayoutCalculator`, and a Trade
/// button that always succeeds — this is a **simulated** trade. No order is sent and
/// nothing persists; Trade plays a short success animation with `successCaption`, then
/// auto-dismisses.
///
/// The sheet never uses the system keyboard: `DSNumberPad` owns all amount entry, so the
/// layout below it is fixed and the amount stays on screen while typing.
///
/// **Geoblocking is enforced here, not at the call sites.** The sheet is presented from
/// six screens, so gating each one would be six chances to miss one; reading
/// `\.tradingAccess` inside the sheet gates every entry point, including future ones.
public struct TradeSheet: View {
    /// Dismisses the sheet (used after the success animation).
    @Environment(\.dismiss) private var dismiss
    /// Whether the user's region may open a position. Injected by `RootView`; defaults
    /// to `.allowed` so previews and tests aren't gated by accident.
    @Environment(\.tradingAccess) private var tradingAccess
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
            // Checked before every other state: a gated user must never reach the pad,
            // the confirm button, or a success screen.
            if !tradingAccess.canOpenPosition {
                // Centred in the sheet's full height — the gate is the whole content
                // here, not a banner above a form.
                Spacer(minLength: 0)
                TradingGateView(access: tradingAccess) { dismiss() }
                Spacer(minLength: 0)
            } else if viewModel.phase == .success {
                successView
            } else {
                sideToggle
                Spacer(minLength: 0)
                amountBlock
                toWinRow
                Spacer(minLength: 0)
                quickAmountRow
                DSNumberPad(
                    secondaryKey: .decimal,
                    onDigit: viewModel.appendDigit,
                    onSecondary: viewModel.appendDecimal,
                    onBackspace: viewModel.backspace,
                    onClear: viewModel.clear
                )
                confirmButton
            }
        }
        .padding(DSLayout.margin)
        .frame(maxHeight: .infinity)
        .background(DSColor.background)
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

    /// Yes/No side picker — switches the traded side in place, updating the payout and
    /// subtitle. Both sides are raised 3D keys; the selected one sinks onto its lip and
    /// takes its green/red tint, so "which side am I on" reads as physical state rather
    /// than just colour.
    private var sideToggle: some View {
        HStack(spacing: DSLayout.spacingMedium) {
            sideKey(.yes, title: "Yes", tint: DSColor.positive, fill: DSColor.positiveTint)
            sideKey(.no, title: "No", tint: DSColor.negative, fill: DSColor.negativeTint)
        }
        .sensoryFeedback(.selection, trigger: viewModel.side)
    }

    /// Builds one Yes/No key, tinted and held down when it's the selected side.
    /// - Parameters:
    ///   - side: The side this key selects.
    ///   - title: The key label.
    ///   - tint: The text/foreground colour when selected.
    ///   - fill: The face fill when selected.
    private func sideKey(_ side: Side, title: String, tint: Color, fill: Color) -> some View {
        let selected = viewModel.side == side
        return Button {
            viewModel.setSide(side)
        } label: {
            Text(title)
                .font(DSFont.subheadline.bold())
                .foregroundStyle(selected ? tint : DSColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSLayout.spacingMedium)
        }
        .buttonStyle(.plain)
        .dsRaised(
            face: selected ? fill : DSColor.surfaceElevated,
            lip: selected ? DSLip.tint(fill) : DSLip.surface,
            isPressed: selected
        )
    }

    /// The +$1/+$5/+$10/+$100 quick-add keys, raised to match the pad below them.
    private var quickAmountRow: some View {
        HStack(spacing: DSLayout.spacingMedium) {
            ForEach([1, 5, 10, 100], id: \.self) { amount in
                Button {
                    viewModel.addAmount(amount)
                } label: {
                    Text("+$\(amount)")
                        .font(DSFont.subheadline.bold())
                        .foregroundStyle(DSColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSLayout.spacingMedium)
                }
                .buttonStyle(
                    DSRaisedButtonStyle(
                        face: DSColor.surfaceElevated,
                        lip: DSLip.surface,
                        depth: DSDepth.small
                    )
                )
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

    /// The Trade/Confirm button, showing a spinner while submitting. Takes the side's
    /// own colour so the primary action matches the side being traded.
    private var confirmButton: some View {
        Button {
            Task { await viewModel.confirm() }
        } label: {
            Group {
                if viewModel.phase == .submitting {
                    ProgressView().tint(.white)
                } else {
                    Text("Trade \(viewModel.outcomeTitle)")
                }
            }
        }
        .modifier(SideActionStyle(side: viewModel.side))
        .disabled(!viewModel.isConfirmEnabled)
    }

    /// The success state: an animated checkmark, trade receipt card, and Done button.
    private var successView: some View {
        VStack(spacing: DSLayout.spacingLarge) {
            Spacer(minLength: 0)

            // Animated Success Icon
            ZStack {
                Circle()
                    .fill(DSColor.positive.opacity(0.15))
                    .frame(width: 76, height: 76)
                Circle()
                    .stroke(DSColor.positive.opacity(0.35), lineWidth: 2)
                    .frame(width: 76, height: 76)
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(DSColor.positive)
            }
            .transition(.scale.combined(with: .opacity))

            // Title & Subtitle
            VStack(spacing: DSLayout.spacingXSmall) {
                Text("Order Placed!")
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.textPrimary)
                Text(viewModel.successCaption)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Receipt Summary Card
            VStack(spacing: DSLayout.spacingMedium) {
                // Market and Outcome Row
                HStack(spacing: DSLayout.spacingSmall) {
                    CardIcon(url: viewModel.market.imageURL)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.market.groupItemTitle ?? viewModel.market.question)
                            .font(DSFont.subheadline.bold())
                            .foregroundStyle(DSColor.textPrimary)
                            .lineLimit(1)
                        Text(viewModel.outcomeTitle)
                            .font(DSFont.caption.bold())
                            .foregroundStyle(viewModel.side == .yes ? DSColor.positive : DSColor.negative)
                    }
                    Spacer()
                    // Traded Price pill
                    Text("\(viewModel.priceCents)¢")
                        .font(DSFont.subheadline.bold())
                        .foregroundStyle(DSColor.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(DSColor.surface)
                        .clipShape(Capsule())
                }

                Divider().overlay(DSColor.separator)

                // Key-value breakdown
                VStack(spacing: DSLayout.spacingSmall) {
                    receiptRow(title: "Amount Invested", value: MarketFormatting.currency(viewModel.amountUSD))
                    receiptRow(title: "Contracts / Shares", value: "\(MarketFormatting.shares(viewModel.potential.shares)) shares")
                    receiptRow(title: "Potential Payout", value: MarketFormatting.currency(viewModel.potential.payoutUSD), valueColor: DSColor.positive)
                }
            }
            .padding(DSLayout.margin)
            .background(DSColor.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.cardRadius, style: .continuous)
                    .stroke(DSColor.separator, lineWidth: 0.5)
            )

            Spacer(minLength: 0)

            // Done Action Button
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(DSFont.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DSLayout.spacingMedium)
            }
            .buttonStyle(.plain)
            .dsRaised(
                face: DSColor.surfaceElevated,
                lip: DSLip.surface,
                isPressed: false
            )
        }
        .padding(.vertical, DSLayout.spacing)
        .sensoryFeedback(.success, trigger: viewModel.phase)
        .animation(.easeOut(duration: 0.25), value: viewModel.phase)
    }

    private func receiptRow(title: String, value: String, valueColor: Color = DSColor.textPrimary) -> some View {
        HStack {
            Text(title)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
            Spacer()
            Text(value)
                .font(DSFont.subheadline.bold())
                .foregroundStyle(valueColor)
        }
    }
}

/// Applies the raised buy-Yes (green) or buy-No (red) button style for `side`. A
/// `ViewModifier` rather than an inline `if`, because the two styles are different
/// types and swapping them inside the view builder would rebuild the button's identity
/// — losing the press animation mid-tap.
private struct SideActionStyle: ViewModifier {
    /// The side currently being traded.
    let side: Side

    @ViewBuilder
    func body(content: Content) -> some View {
        switch side {
        case .yes: content.buttonStyle(DSBuyYesButtonStyle())
        case .no: content.buttonStyle(DSBuyNoButtonStyle())
        }
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

//
//  PortfolioView.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import PortfolioDomain
import DesignSystem

public struct PortfolioView: View {
    @State private var viewModel: PortfolioViewModel

    public init(viewModel: PortfolioViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        content
            .navigationTitle("Portfolio")
            .toolbar {
                if viewModel.address != nil {
                    Button("Change") { viewModel.changeWallet() }
                }
            }
            .task { await viewModel.start() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .needsAddress:
            addressEntry
        case .loading:
            StateView(.loading)
        case .empty:
            StateView(.empty)
        case .failed(let message):
            StateView(.error(message))
        case .loaded(let portfolio):
            dashboard(portfolio)
        }
    }

    // MARK: Address entry

    private var addressEntry: some View {
        VStack(spacing: DSLayout.spacingLarge) {
            Image(systemName: "wallet.pass")
                .font(.largeTitle)
                .foregroundStyle(DSColor.accent)
            Text("Watch a wallet")
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
            Text("Enter any NextOutcome wallet address to track its positions and PnL. Read-only.")
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(.center)

            TextField("0x…", text: $viewModel.addressInput)
                .textFieldStyle(.plain)
                .padding()
                .background(DSColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            if let error = viewModel.inputError {
                Text(error)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.negative)
            }

            Button {
                Task { await viewModel.submit() }
            } label: {
                Text("Track wallet")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DSPrimaryButtonStyle())
        }
        .padding(DSLayout.margin)
        .frame(maxHeight: .infinity, alignment: .center)
        .background(DSColor.background)
    }

    // MARK: Dashboard

    private func dashboard(_ portfolio: Portfolio) -> some View {
        ScrollView {
            VStack(spacing: DSLayout.spacing) {
                ValuePnLHeader(
                    title: "Portfolio value",
                    value: PortfolioFormatting.usd(portfolio.value),
                    change: PortfolioFormatting.signedUSD(portfolio.totalCashPnl)
                        + " (" + PortfolioFormatting.signedPercent(portfolio.totalPercentPnl) + ")",
                    isPositive: portfolio.totalCashPnl >= 0,
                    sparkData: []
                )

                sectionHeader("Open positions")
                ForEach(portfolio.positions) { position in
                    PositionRow(position: position)
                }

                if !viewModel.closedPositions.isEmpty {
                    sectionHeader("Closed positions")
                    ForEach(viewModel.closedPositions) { closed in
                        ClosedPositionRow(position: closed)
                    }
                }
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.top, DSLayout.spacing)
        }
        .background(DSColor.background)
        .refreshable { await viewModel.refresh() }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(DSFont.caption.bold())
                .foregroundStyle(DSColor.textSecondary)
            Spacer()
        }
        .padding(.top, DSLayout.spacing)
    }
}

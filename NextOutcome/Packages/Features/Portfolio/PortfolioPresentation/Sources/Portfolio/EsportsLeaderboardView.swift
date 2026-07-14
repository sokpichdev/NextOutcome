//
//  EsportsLeaderboardView.swift
//  NextOutcome
//
//  Created by Sok Pich on 14/07/2026.
//

import SwiftUI
import PortfolioDomain
import DesignSystem

/// The Esports hub's Leaderboard tab: a period dropdown (Monthly/Weekly/…), a
/// Profit/Volume sort menu, and the ranked esports traders with X badges and green
/// profit amounts — matching web's esports leaderboard.
///
/// Embedded inside the Esports hub's scroll view, so it renders as a plain column
/// rather than its own scroll container.
public struct EsportsLeaderboardView: View {
    /// The view model driving the tab.
    @State private var viewModel: EsportsLeaderboardViewModel

    /// Creates the view.
    /// - Parameter viewModel: The esports leaderboard view model.
    public init(viewModel: EsportsLeaderboardViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            controls
            content
        }
        .task { await viewModel.loadIfNeeded() }
    }

    /// The period dropdown + metric sort menu row.
    private var controls: some View {
        HStack {
            Menu {
                ForEach(LeaderboardWindow.allCases, id: \.self) { window in
                    Button(window.menuTitle) { viewModel.window = window }
                }
            } label: {
                HStack(spacing: DSLayout.spacingXSmall) {
                    Text(viewModel.window.menuTitle).font(DSFont.subheadline.bold())
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(DSColor.textPrimary)
                .padding(.horizontal, DSLayout.spacingMedium)
                .padding(.vertical, DSLayout.spacingSmall)
                .background(DSColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
            }

            Spacer()

            Menu {
                ForEach(LeaderboardMetric.allCases, id: \.self) { metric in
                    Button(metric == .profit ? "Profit/Loss" : "Volume") { viewModel.metric = metric }
                }
            } label: {
                HStack(spacing: DSLayout.spacingXSmall) {
                    Text(viewModel.metric == .profit ? "Profit/Loss" : "Volume")
                        .font(DSFont.subheadline.bold())
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(DSColor.textPrimary)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            VStack(spacing: DSLayout.spacingSmall) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: DSLayout.cardRadius)
                        .fill(DSColor.surface)
                        .frame(height: 64)
                }
            }
            .redacted(reason: .placeholder)
        case .empty:
            Text("No rankings for this period yet.")
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        case .failed(let message):
            StateView(.error(message))
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        case .loaded(let entries):
            LazyVStack(spacing: DSLayout.spacingSmall) {
                ForEach(entries) { entry in
                    row(entry)
                }
            }
        }
    }

    /// One ranked trader row: rank, avatar, name (+X badge), and the ranked amount.
    private func row(_ entry: LeaderboardEntry) -> some View {
        HStack(spacing: DSLayout.spacing) {
            Text("\(entry.rank)")
                .font(DSFont.subheadline.bold())
                .foregroundStyle(entry.rank <= 3 ? DSColor.accent : DSColor.textSecondary)
                .frame(width: 26, alignment: .leading)

            avatar(entry)

            Text(entry.name)
                .font(DSFont.subheadline.bold())
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)

            if entry.xUsername != nil {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(DSColor.textPrimary)
                    .padding(5)
                    .background(DSColor.surfaceElevated)
                    .clipShape(Circle())
            }
            if entry.verifiedBadge {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(DSColor.accent)
            }

            Spacer()

            Text(amountLabel(entry))
                .font(DSFont.subheadline.bold())
                .foregroundStyle(amountColor(entry))
        }
        .padding(.vertical, DSLayout.spacingSmall)
        .overlay(alignment: .bottom) {
            Divider().overlay(DSColor.surfaceElevated)
        }
    }

    /// "+$981,077" for profit (signed, green/red), plain dollars for volume.
    private func amountLabel(_ entry: LeaderboardEntry) -> String {
        let base = PortfolioFormatting.wholeUSD(abs(entry.amount))
        guard viewModel.metric == .profit else { return base }
        return entry.amount < 0 ? "-\(base)" : "+\(base)"
    }

    private func amountColor(_ entry: LeaderboardEntry) -> Color {
        guard viewModel.metric == .profit else { return DSColor.textPrimary }
        return entry.amount < 0 ? DSColor.negative : DSColor.positive
    }

    @ViewBuilder
    private func avatar(_ entry: LeaderboardEntry) -> some View {
        AsyncImage(url: entry.profileImageURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Circle().fill(DSColor.surfaceElevated)
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
    }
}

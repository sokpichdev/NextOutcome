//
//  HoldersSection.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// Top-holders card for the Market Detail screen.
struct HoldersSection: View {
    @State private var viewModel: HoldersViewModel

    init(viewModel: HoldersViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                Text("Top holders")
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                content
            }
        }
        .task { if case .loading = viewModel.state { await viewModel.load() } }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView().tint(DSColor.accent).frame(maxWidth: .infinity).padding(.vertical, 8)
        case .empty, .failed:
            Text("No holder data")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        case .loaded(let holders):
            VStack(spacing: DSLayout.spacing) {
                ForEach(holders) { HolderRow(holder: $0) }
            }
        }
    }
}

private struct HolderRow: View {
    let holder: Holder

    var body: some View {
        HStack(spacing: DSLayout.spacing) {
            avatar
            Text(holder.name)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
            if !holder.outcome.isEmpty {
                StatusBadge(holder.outcome, color: holder.outcome == "Yes" ? DSColor.positive : DSColor.negative)
            }
            Spacer()
            Text(shares)
                .font(DSFont.caption.bold())
                .foregroundStyle(DSColor.textSecondary)
        }
    }

    private var shares: String {
        let value = NSDecimalNumber(decimal: holder.shares).doubleValue
        switch value {
        case 1_000_000...: return String(format: "%.1fM", value / 1_000_000)
        case 1_000...: return String(format: "%.1fK", value / 1_000)
        default: return String(Int(value.rounded()))
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = holder.profileImageURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                DSColor.surfaceElevated
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        } else {
            Circle().fill(DSColor.surfaceElevated).frame(width: 28, height: 28)
        }
    }
}

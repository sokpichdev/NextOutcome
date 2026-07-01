//
//  AccountView.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import DesignSystem
import PortfolioPresentation

/// Simple Account hub. For now it surfaces the global leaderboard; account
/// settings/auth arrive with the trading phases.
struct AccountView: View {
    let leaderboardViewModel: LeaderboardViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: DSLayout.spacing) {
                NavigationLink {
                    LeaderboardView(viewModel: leaderboardViewModel)
                } label: {
                    row(title: "Leaderboard", systemImage: "trophy")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.top, DSLayout.spacing)
        }
        .background(DSColor.background)
        .navigationTitle("Account")
    }

    private func row(title: String, systemImage: String) -> some View {
        DSCard {
            HStack(spacing: DSLayout.spacing) {
                Image(systemName: systemImage)
                    .foregroundStyle(DSColor.accent)
                Text(title)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
    }
}

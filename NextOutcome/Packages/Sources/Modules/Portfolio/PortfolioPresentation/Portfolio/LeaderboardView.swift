//
//  LeaderboardView.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import PortfolioDomain
import DesignSystem

/// The leaderboard screen: a metric picker and window chips above a ranked list of traders.
public struct LeaderboardView: View {
    /// The view model driving the screen.
    @State private var viewModel: LeaderboardViewModel

    /// Creates the view.
    /// - Parameter viewModel: The leaderboard view model.
    public init(viewModel: LeaderboardViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            controls
            content
        }
        .background(DSColor.background)
        .navigationTitle("Leaderboard")
        .task { if case .loading = viewModel.state { await viewModel.load() } }
    }

    /// The metric segmented picker (Volume/Profit) and the time-window chips.
    private var controls: some View {
        HStack {
            Picker("Metric", selection: $viewModel.metric) {
                ForEach(LeaderboardMetric.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 6) {
                ForEach(LeaderboardWindow.allCases, id: \.self) { window in
                    DSChip(window.title, isActive: viewModel.window == window) {
                        viewModel.window = window
                    }
                }
            }
        }
        .padding(.horizontal, DSLayout.margin)
        .padding(.vertical, DSLayout.spacing)
    }

    /// Switches on the view model's state to show loading/empty/error states or the ranked
    /// list of `LeaderboardRow`s.
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            StateView(.loading)
        case .empty:
            StateView(.empty)
        case .failed(let message):
            StateView(.error(message))
        case .loaded(let entries):
            ScrollView {
                LazyVStack(spacing: DSLayout.spacing) {
                    ForEach(entries) { entry in
                        LeaderboardRow(entry: entry, metric: viewModel.metric)
                    }
                }
                .padding(.horizontal, DSLayout.margin)
                .padding(.top, DSLayout.spacing)
            }
        }
    }
}

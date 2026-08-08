//
//  BreakingView.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// The Breaking feed: a dated hero banner, a row of category sub-pills, and a numbered list
/// of the biggest 24h market movers. Tapping a row opens the bespoke movers detail chart.
public struct BreakingView: View {
    /// The view model driving the movers feed.
    @State private var viewModel: BreakingViewModel
    /// Builds the movers-detail view model when a row is tapped (injected by `AppContainer`).
    @Environment(\.moversDetailFactory) private var moversDetailFactory

    /// Creates the view.
    /// - Parameter viewModel: The Breaking feed view model.
    public init(viewModel: BreakingViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSLayout.spacing) {
                BreakingHeroBanner()
                categoryPills
                moversContent
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.vertical, DSLayout.spacing)
        }
        .background(DSColor.background)
        .navigationDestination(for: Mover.self) { mover in
            if let factory = moversDetailFactory {
                MoversDetailView(viewModel: factory(mover))
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.reload() }
    }

    /// The horizontally-scrolling category sub-pill row (All / Politics / World / …).
    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSLayout.spacingSmall) {
                ForEach(BreakingCategory.allCases) { category in
                    DSChip(category.title, isActive: category == viewModel.category) {
                        Task { await viewModel.select(category) }
                    }
                }
            }
        }
    }

    /// The movers list, or a loading/empty/error placeholder for the current state.
    @ViewBuilder
    private var moversContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            StateView(.loading).frame(height: 320)
        case .empty:
            StateView(.empty).frame(height: 320)
        case .failed(let message):
            StateView(.error(message)).frame(height: 320)
        case .loaded(let movers):
            ForEach(Array(movers.enumerated()), id: \.element.id) { index, mover in
                NavigationLink(value: mover) {
                    MoverRow(rank: index + 1, mover: mover)
                }
                .buttonStyle(.plain)
                if index < movers.count - 1 {
                    Divider().overlay(DSColor.separator)
                }
            }
        }
    }
}

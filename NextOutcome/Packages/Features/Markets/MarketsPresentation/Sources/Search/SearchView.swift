//
//  SearchView.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//


import SwiftUI
import MarketsDomain
import DesignSystem

/// The market search screen: a search field over a results list, with prompt/empty/error
/// states. Results are flat markets (no parent event).
public struct SearchView: View {
    /// The view model driving search.
    @State private var viewModel: SearchViewModel

    /// Creates the view.
    /// - Parameter viewModel: The search view model.
    public init(viewModel: SearchViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        content
            .navigationTitle("Search")
            .navigationDestination(for: Market.self) { market in
                // Search results are flat markets with no parent event attached (Gamma's
                // market-search endpoint doesn't return one), so there is no real event id
                // to thread here; MarketDetailView hides its Comments strip in that case.
                MarketDetailView(market: market)
            }
            .searchable(
                text: Binding(
                    get: { viewModel.query },
                    set: { viewModel.queryChanged($0) }
                ),
                prompt: "Search markets"
            )
    }

    /// Switches on the view model's state to show the prompt, loading/empty/error states, or
    /// the results list.
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            prompt
        case .loading:
            StateView(.loading)
        case .empty:
            StateView(.empty)
        case .failed(let message):
            StateView(.error(message))
        case .results(let markets):
            results(markets)
        }
    }

    /// The idle-state prompt shown before the user types a query.
    private var prompt: some View {
        VStack(spacing: DSLayout.spacing) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(DSColor.textSecondary)
            Text("Search NextOutcome markets")
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
    }

    /// The scrolling list of matching market cards.
    /// - Parameter markets: The search results to show.
    private func results(_ markets: [Market]) -> some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.spacing) {
                ForEach(markets) { market in
                    NavigationLink(value: market) {
                        MarketCard(market: market)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.top, DSLayout.spacing)
        }
        .background(DSColor.background)
    }
}
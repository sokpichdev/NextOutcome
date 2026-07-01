//
//  SearchView.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//


import SwiftUI
import MarketsDomain
import DesignSystem

public struct SearchView: View {
    @State private var viewModel: SearchViewModel

    public init(viewModel: SearchViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        content
            .navigationTitle("Search")
            .navigationDestination(for: Market.self) { market in
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

    private var prompt: some View {
        VStack(spacing: DSLayout.spacing) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(DSColor.textSecondary)
            Text("Search Polymarket markets")
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
    }

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
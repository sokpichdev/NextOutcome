//
//  RootView.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import DesignSystem
import MarketsPresentation
import OrderbookPresentation
import PortfolioPresentation

struct RootView: View {
    @State private var eventListViewModel: EventListViewModel
    @State private var searchViewModel: SearchViewModel
    @State private var portfolioViewModel: PortfolioViewModel
    private let marketLiveFactory: MarketLiveViewModelFactory

    @MainActor
    init(container: AppContainer = AppContainer()) {
        _eventListViewModel = State(initialValue: container.makeEventListViewModel())
        _searchViewModel = State(initialValue: container.makeSearchViewModel())
        _portfolioViewModel = State(initialValue: container.makePortfolioViewModel())
        marketLiveFactory = container.makeMarketLiveFactory()
    }

    var body: some View {
        TabView {
            NavigationStack {
                EventListView(viewModel: eventListViewModel)
            }
            .tabItem { Label("Markets", systemImage: "chart.line.uptrend.xyaxis") }

            NavigationStack {
                SearchView(viewModel: searchViewModel)
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack {
                PortfolioView(viewModel: portfolioViewModel)
            }
            .tabItem { Label("Portfolio", systemImage: "chart.pie") }

            NavigationStack { ComingSoonView(title: "Activity") }
                .tabItem { Label("Activity", systemImage: "bolt.horizontal") }

            NavigationStack { ComingSoonView(title: "Account") }
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .tint(DSColor.accent)
        .environment(\.marketLiveFactory, marketLiveFactory)
    }
}

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
    @State private var activityViewModel: ActivityViewModel
    @State private var shellViewModel: ShellViewModel
    private let leaderboardViewModel: LeaderboardViewModel
    private let marketLiveFactory: MarketLiveViewModelFactory
    private let marketHoldersFactory: MarketHoldersViewModelFactory

    @State private var selectedCategory: ShellCategory = .trending
    @State private var isDrawerOpen = false

    @MainActor
    init(container: AppContainer = AppContainer()) {
        let portfolio = container.makePortfolioViewModel()
        _eventListViewModel = State(initialValue: container.makeEventListViewModel())
        _searchViewModel = State(initialValue: container.makeSearchViewModel())
        _portfolioViewModel = State(initialValue: portfolio)
        _activityViewModel = State(initialValue: container.makeActivityViewModel())
        _shellViewModel = State(initialValue: ShellViewModel(portfolio: portfolio))
        leaderboardViewModel = container.makeLeaderboardViewModel()
        marketLiveFactory = container.makeMarketLiveFactory()
        marketHoldersFactory = container.makeMarketHoldersFactory()
    }

    var body: some View {
        ZStack(alignment: .leading) {
            tabs
            if isDrawerOpen { drawerOverlay }
        }
        .tint(DSColor.accent)
        .animation(.easeInOut(duration: 0.3), value: isDrawerOpen)
        .environment(\.marketLiveFactory, marketLiveFactory)
        .environment(\.marketHoldersFactory, marketHoldersFactory)
    }

    private var tabs: some View {
        TabView {
            NavigationStack {
                chrome { EventListView(viewModel: eventListViewModel) }
            }
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                chrome { SearchView(viewModel: searchViewModel) }
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack {
                chrome { ActivityView(viewModel: activityViewModel) }
            }
            .tabItem { Label("Breaking", systemImage: "circle.dashed") }

            NavigationStack {
                chrome { PortfolioView(viewModel: portfolioViewModel) }
            }
            .tabItem { Label(shellViewModel.balanceLabel, systemImage: "chart.line.uptrend.xyaxis") }
        }
    }

    @ViewBuilder
    private func chrome<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ShellChrome(
            selectedCategory: $selectedCategory,
            onAvatar: { isDrawerOpen = true }
        ) { content() }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var drawerOverlay: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { isDrawerOpen = false }
            SideMenuDrawer(
                addressShort: shellViewModel.addressShort,
                onSelect: { _ in isDrawerOpen = false },
                onLogout: { isDrawerOpen = false }
            )
            .frame(width: 320)
            .transition(.move(edge: .leading))
        }
    }
}

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
import LiveStatsDomain
import LiveStatsPresentation
import PortfolioPresentation
import TradingDomain

/// The top-level screen of the app: a four-tab layout (Home, Search, Breaking,
/// Portfolio) with a side drawer that can slide in from the left.
///
/// `RootView` owns the long-lived view models and the shared factories/services. It
/// holds the tab-driving view models in `@State` so their loaded data survives when the
/// user switches tabs, and it injects the factories into the SwiftUI environment so deep
/// child screens can build their own view models without importing the Data layer.
struct RootView: View {
    // These view models are stored on the root view so their data stays alive
    // even when the user switches between tabs.

    /// Drives the Home tab's market/event feed.
    @State private var eventListViewModel: EventListViewModel
    /// Drives the World Cup hub shown in the Home tab when that category is selected.
    @State private var worldCupViewModel: WorldCupHubViewModel
    /// Drives the Breaking movers feed shown in the Home tab when that category is selected.
    @State private var breakingViewModel: BreakingViewModel
    /// Drives the Politics hub shown in the Home tab when that category is selected.
    @State private var politicsHubViewModel: PoliticsHubViewModel
    /// Drives the Search tab.
    @State private var searchViewModel: SearchViewModel
    /// Drives the Portfolio tab.
    @State private var portfolioViewModel: PortfolioViewModel
    /// Provides shell-level state such as the balance label shown on the Portfolio tab.
    @State private var shellViewModel: ShellViewModel

    // Factories and services below are handed to child views through the SwiftUI
    // environment. They aren't `@State` because they're immutable and don't drive UI.

    /// View model for the leaderboard screen reached from the drawer.
    private let leaderboardViewModel: LeaderboardViewModel
    /// Lazily builds a live market view model once a detail screen knows its asset ID.
    private let marketLiveFactory: MarketLiveViewModelFactory
    /// Lazily builds an order book view model for a given asset ID.
    private let orderbookFactory: OrderbookViewModelFactory
    /// Lazily builds the "top holders" view model for a market's condition ID.
    private let marketHoldersFactory: MarketHoldersViewModelFactory
    /// Lazily builds the event detail social strip view model.
    private let socialStripFactory: SocialStripViewModelFactory
    /// Lazily builds the bespoke movers detail view model when a Breaking row is tapped.
    private let moversDetailFactory: MoversDetailViewModelFactory
    /// Supplies price-history data to charts without exposing the Data layer.
    private let priceHistoryProvider: PriceHistoryProvider
    /// Lazily builds the BTC 5-minute live screen view model.
    private let btcLiveFactory: BTCLiveViewModelFactory
    /// Handles (simulated) order submission for the mock trade sheet.
    private let tradeSubmitter: TradeSubmitting
    /// Streams live sports-stats updates to the Live sub-tab.
    private let sportsStreamer: any SportsStateStreaming

    /// Which feed category the Home tab currently shows (e.g. trending, World Cup).
    @State private var selectedCategory: ShellCategory = .trending
    /// Whether the side drawer is currently slid in over the main content.
    @State private var isDrawerOpen = false

    /// Builds the root view, resolving every view model and factory from the container.
    ///
    /// Everything is created exactly once here at launch so switching tabs never rebuilds
    /// (and thus never reloads) a screen's state.
    /// - Parameter container: The composition root that vends dependencies. Defaults to a
    ///   fresh `AppContainer`; inject a custom one in previews or tests.
    @MainActor
    init(container: AppContainer = AppContainer()) {
        // Create all required view models and helper objects once when the app starts.
        // The container hides how each object is built so the root view stays simple.
        let portfolio = container.makePortfolioViewModel()
        _eventListViewModel = State(initialValue: container.makeEventListViewModel())
        _worldCupViewModel = State(initialValue: container.makeWorldCupHubViewModel())
        _breakingViewModel = State(initialValue: container.makeBreakingViewModel())
        let politics = container.makePoliticsHubViewModel()
        _politicsHubViewModel = State(initialValue: politics)
        // Kicked off here (an unstructured Task, not a SwiftUI `.task` view modifier) so the
        // fetch survives category/navigation churn — it isn't tied to any view's presence in
        // the hierarchy and can't be cancelled by scrolling, tab switches, or re-renders.
        Task { await politics.loadIfNeeded() }
        _searchViewModel = State(initialValue: container.makeSearchViewModel())
        _portfolioViewModel = State(initialValue: portfolio)
        _shellViewModel = State(initialValue: ShellViewModel(portfolio: portfolio))

        leaderboardViewModel = container.makeLeaderboardViewModel()
        marketLiveFactory = container.makeMarketLiveFactory()
        orderbookFactory = container.makeOrderbookFactory()
        marketHoldersFactory = container.makeMarketHoldersFactory()
        socialStripFactory = container.makeSocialStripFactory()
        moversDetailFactory = container.makeMoversDetailFactory()
        priceHistoryProvider = container.makePriceHistoryProvider()
        btcLiveFactory = container.makeBTCLiveFactory()
        tradeSubmitter = container.makeTradeSubmitter()
        sportsStreamer = container.makeSportsStreamer()
    }

    /// The view hierarchy: the tab bar with the drawer layered on top, plus the shared
    /// factories/services published into the environment for descendant views to read.
    var body: some View {
        // Main app view: tabs plus a drawer that can slide in from the left.
        ZStack(alignment: .leading) {
            tabs
            if isDrawerOpen { drawerOverlay.transition(.move(edge: .leading)) }
        }
        .tint(DSColor.accent)
        .animation(.easeInOut(duration: 0.3), value: isDrawerOpen)
        // Provide shared factories and services to child views through environment keys.
        .environment(\.marketLiveFactory, marketLiveFactory)
        .environment(\.orderbookFactory, orderbookFactory)
        .environment(\.marketHoldersFactory, marketHoldersFactory)
        .environment(\.socialStripFactory, socialStripFactory)
        .environment(\.moversDetailFactory, moversDetailFactory)
        .environment(\.priceHistoryProvider, priceHistoryProvider)
        .environment(\.btcLiveFactory, btcLiveFactory)
        .environment(\.tradeSubmitter, tradeSubmitter)
        .environment(\.sportsStreamer, sportsStreamer)
    }

    /// The four-tab layout. Each tab gets its own `NavigationStack` so navigation depth is
    /// tracked independently per tab.
    private var tabs: some View {
        // A tab view with its own navigation stack for each section.
        TabView {
            NavigationStack {
                chrome {
                    // Home tab content changes depending on the selected shell category.
                    // The view models here are kept at root so the feed state does not
                    // reset when users switch tabs.
                    if selectedCategory == .worldCup {
                        WorldCupHubView(viewModel: worldCupViewModel)
                    } else if selectedCategory == .breaking {
                        BreakingView(viewModel: breakingViewModel)
                    } else {
                        EventListView(
                            viewModel: eventListViewModel,
                            selectedCategory: selectedCategory,
                            politicsHubViewModel: selectedCategory == .politics ? politicsHubViewModel : nil
                        )
                    }
                }
            }
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                chrome(showsCategoryRail: false) { SearchView(viewModel: searchViewModel) }
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack {
                chrome(showsCategoryRail: false) { BreakingView(viewModel: breakingViewModel) }
            }
            .tabItem { Label("Breaking", systemImage: "bolt.fill") }

            NavigationStack {
                chrome(showsCategoryRail: false) { PortfolioView(viewModel: portfolioViewModel) }
            }
            .tabItem { Label(shellViewModel.balanceLabel, systemImage: "chart.line.uptrend.xyaxis") }
        }
    }

    /// Wraps a screen in the shared chrome (top bar + avatar button, optionally the category
    /// rail). Only the Home tab's content responds to the category rail, so every other tab
    /// hides it by passing `showsCategoryRail: false`.
    /// - Parameters:
    ///   - showsCategoryRail: Whether to show the Trending/World Cup/Breaking/… rail below the
    ///     top bar. Defaults to `true` (the Home tab).
    ///   - content: The tab's screen content to embed inside the chrome.
    /// - Returns: The content wrapped in `ShellChrome` with the navigation bar hidden.
    @ViewBuilder
    private func chrome<C: View>(showsCategoryRail: Bool = true, @ViewBuilder _ content: () -> C) -> some View {
        // Wrap each screen in the shared chrome UI used across tabs.
        // This adds the top bar (+ category rail, for Home) and the avatar button that opens the drawer.
        ShellChrome(
            selectedCategory: $selectedCategory,
            showsCategoryRail: showsCategoryRail,
            onAvatar: { isDrawerOpen = true }
        ) { content() }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// The side menu drawer plus its dimmed backdrop. Tapping the backdrop closes it.
    private var drawerOverlay: some View {
        // Drawer overlay appears above the main content. A tap outside
        // closes the drawer.
        ZStack(alignment: .leading) {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { isDrawerOpen = false }
            SideMenuDrawer(
                addressShort: shellViewModel.addressShort,
                onSelect: { _ in isDrawerOpen = false },
                onLogout: { isDrawerOpen = false }
            )
            .frame(width: 320)
        }
    }
}

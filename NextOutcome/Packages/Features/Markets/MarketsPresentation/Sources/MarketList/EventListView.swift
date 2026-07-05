//
//  EventListView.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// The main markets feed screen: secondary filter row, optional trending chips, and an
/// infinitely-scrolling list of `HomeCard`s, with navigation to event/market detail.
public struct EventListView: View {
    /// The view model driving the feed.
    @State private var viewModel: EventListViewModel
    /// The category selected in the shell rail, applied to the view model.
    private let selectedCategory: ShellCategory
    /// The Politics hub view model, non-nil only when `selectedCategory == .politics` — drives
    /// the "2026 Midterms Predictions" promo card prepended to the feed in that category.
    private let politicsHubViewModel: PoliticsHubViewModel?

    /// Creates the view.
    /// - Parameters:
    ///   - viewModel: The event-list view model.
    ///   - selectedCategory: The initial rail category. Defaults to trending.
    ///   - politicsHubViewModel: The Politics hub view model, when in the Politics category.
    public init(
        viewModel: EventListViewModel,
        selectedCategory: ShellCategory = .trending,
        politicsHubViewModel: PoliticsHubViewModel? = nil
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.selectedCategory = selectedCategory
        self.politicsHubViewModel = politicsHubViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            SearchFilterRow(viewModel: viewModel)
            // Outside `content` so the row stays visible while a chip re-query is loading.
            if viewModel.showsTrendingChips {
                TrendingChipRow(
                    chips: viewModel.trendingChips,
                    selectedTagID: viewModel.selectedTrendingTagID,
                    onSelect: { id in Task { await viewModel.selectTrendingChip(tagID: id) } }
                )
            }
            if viewModel.filterRowVisible {
                AdvancedFilterRow(viewModel: viewModel)
            }
            content
        }
        .background(DSColor.background)
        .navigationDestination(for: Event.self) { EventDetailView(event: $0) }
        .navigationDestination(for: MarketNavigationTarget.self) {
            MarketDetailView(market: $0.market, eventID: $0.eventID)
        }
        .navigationDestination(for: MidtermsHubDestination.self) { _ in
            if let politicsHubViewModel { PoliticsHubView(viewModel: politicsHubViewModel) }
        }
        // `apply` is idempotent and loads on first appearance; it also resyncs the VM when
        // the view remounts with a different category (e.g. returning from the hub).
        // (The Politics hub's own data is loaded independently — see `RootView.init` — since
        // a view-tied `.task` here was getting cancelled by navigation/category churn.)
        .task { await viewModel.apply(category: selectedCategory) }
        .onChange(of: selectedCategory) { _, new in Task { await viewModel.apply(category: new) } }
        // Debounced search: SwiftUI cancels and restarts this on every `searchQuery`
        // keystroke, so only the last one (after the delay) actually calls the API.
        .task(id: viewModel.searchQuery) {
            guard viewModel.isSearchActive else { await viewModel.performSearch(); return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await viewModel.performSearch()
        }
    }

    /// Switches on the view model's state (or search state, while searching) to show
    /// loading/empty/error states or the feed.
    @ViewBuilder
    private var content: some View {
        if viewModel.isSearchActive {
            if viewModel.isSearching && viewModel.visibleEvents.isEmpty {
                StateView(.loading)
            } else if viewModel.visibleEvents.isEmpty {
                StateView(.empty)
            } else {
                feed
            }
        } else {
            switch viewModel.state {
            case .idle, .loading: StateView(.loading)
            case .empty:          StateView(.empty)
            case .failed(let m):  StateView(.error(m))
            case .loaded:         feed
            }
        }
    }

    /// The scrolling list of cards. The last row triggers `loadMore()` for infinite scroll,
    /// and the whole list supports pull-to-refresh.
    private var feed: some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.spacing) {
                if let politicsHubViewModel {
                    NavigationLink(value: MidtermsHubDestination()) {
                        MidtermsPromoCard(viewModel: politicsHubViewModel)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(viewModel.visibleEvents) { event in
                    NavigationLink(value: event) {
                        HomeCard(event: event)
                    }
                    .buttonStyle(.plain)
                    .onAppear { Task { if event.id == viewModel.visibleEvents.last?.id { await viewModel.loadMore() } } }
                }
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.vertical, DSLayout.spacing)
        }
        .refreshable { await viewModel.refresh() }
    }
}

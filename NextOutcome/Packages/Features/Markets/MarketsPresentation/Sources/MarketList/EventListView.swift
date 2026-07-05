//
//  EventListView.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

public struct EventListView: View {
    @State private var viewModel: EventListViewModel
    private let selectedCategory: ShellCategory

    public init(viewModel: EventListViewModel, selectedCategory: ShellCategory = .trending) {
        self._viewModel = State(initialValue: viewModel)
        self.selectedCategory = selectedCategory
    }

    public var body: some View {
        VStack(spacing: 0) {
            SecondaryFilterRow(viewModel: viewModel)
            // Outside `content` so the row stays visible while a chip re-query is loading.
            if viewModel.showsTrendingChips {
                TrendingChipRow(
                    chips: viewModel.trendingChips,
                    selectedTagID: viewModel.selectedTrendingTagID,
                    onSelect: { id in Task { await viewModel.selectTrendingChip(tagID: id) } }
                )
            }
            content
        }
        .background(DSColor.background)
        .navigationDestination(for: Event.self) { EventDetailView(event: $0) }
        .navigationDestination(for: MarketNavigationTarget.self) {
            MarketDetailView(market: $0.market, eventID: $0.eventID)
        }
        // `apply` is idempotent and loads on first appearance; it also resyncs the VM when
        // the view remounts with a different category (e.g. returning from the hub).
        .task { await viewModel.apply(category: selectedCategory) }
        .onChange(of: selectedCategory) { _, new in Task { await viewModel.apply(category: new) } }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading: StateView(.loading)
        case .empty:          StateView(.empty)
        case .failed(let m):  StateView(.error(m))
        case .loaded:         feed
        }
    }

    private var feed: some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.spacing) {
                ForEach(viewModel.visibleEvents) { event in
                    NavigationLink(value: event) {
                        HomeCard(event: event, kindOverride: heroID == event.id ? .hero : nil)
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

    /// The first sports event in the visible feed becomes the hero slot.
    private var heroID: String? {
        viewModel.visibleEvents.first { HomeCardKind.isSports($0) }?.id
    }
}

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
    
    public init(viewModel: EventListViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            filterBar
            content
        }
        .background(DSColor.background)
            .navigationTitle("Markets")
            .navigationDestination(for: Event.self) { event in
                EventDetailView(event: event)
            }
            .navigationDestination(for: Market.self) { market in
                MarketDetailView(market: market)
            }
            .task {
                if case .idle = viewModel.state { await viewModel.load() }
            }
    }
    
    @ViewBuilder
    private var filterBar: some View {
        if !viewModel.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    DSChip("All", isActive: viewModel.selectedTagID == nil) {
                        Task { await viewModel.select(tagID: nil) }
                    }
                    ForEach(viewModel.tags) { tag in
                        DSChip(tag.label, isActive: viewModel.selectedTagID == tag.id) {
                            Task { await viewModel.select(tagID: tag.id) }
                        }
                    }
                }
                .padding(.horizontal, DSLayout.margin)
                .padding(.vertical, DSLayout.spacing)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading: StateView(.loading)
        case .empty: StateView(.empty)
        case .failed(let message): StateView(.error(message))
        case .loaded(let events): list(events)
        }
    }
    
    private func list(_ events: [Event]) -> some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.spacing) {
                ForEach(events) { event in
                    NavigationLink(value: event) {
                        EventCard(event: event)
                    }
                    .buttonStyle(.plain)
                    .task {
                        if event.id == events.last?.id {
                            await viewModel.loadMore()
                        }
                    }
                }
                
                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(DSColor.accent)
                        .padding()
                }
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.vertical, DSLayout.spacing)
        }
        .background(DSColor.background)
        .refreshable {
            await viewModel.refresh()
        }
    }
}

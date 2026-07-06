//
//  SportsLeagueDetailView.swift
//  NextOutcome
//
//  Created by Sok Pich on 06/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// A single league's detail screen, pushed from a Sports hub chip (e.g. Wimbledon, MLB,
/// UFC): its markets, with a toggleable title search.
public struct SportsLeagueDetailView: View {
    /// The view model driving this league's markets and search state.
    @State private var viewModel: SportsLeagueDetailViewModel

    /// Creates the view.
    /// - Parameters:
    ///   - league: The league this screen shows.
    ///   - fetchEvents: The use case used to load the league's markets.
    public init(league: SportsLeague, fetchEvents: FetchEventsUseCase) {
        self._viewModel = State(initialValue: SportsLeagueDetailViewModel(league: league, fetchEvents: fetchEvents))
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            if viewModel.isSearchActive { searchField }
            content
        }
        .background(DSColor.background)
        .navigationDestination(for: Event.self) { EventDetailView(event: $0) }
        .navigationDestination(for: MarketNavigationTarget.self) {
            MarketDetailView(market: $0.market, eventID: $0.eventID)
        }
        .task { await viewModel.loadIfNeeded() }
    }

    /// The screen's own title row (the app hides the system nav bar), with a search toggle.
    private var header: some View {
        HStack {
            Text(viewModel.league.title)
                .font(DSFont.largeTitle)
                .foregroundStyle(DSColor.textPrimary)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { viewModel.isSearchActive.toggle() }
                if !viewModel.isSearchActive { viewModel.searchQuery = "" }
            } label: {
                Image(systemName: viewModel.isSearchActive ? "xmark.circle.fill" : "magnifyingglass")
                    .foregroundStyle(DSColor.textPrimary)
            }
        }
        .padding(.horizontal, DSLayout.margin)
        .padding(.top, DSLayout.spacing)
    }

    /// The toggleable search field shown above the list.
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(DSColor.textSecondary)
            TextField("Search \(viewModel.league.title)", text: $viewModel.searchQuery)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textPrimary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(DSColor.surface).clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
        .padding(.horizontal, DSLayout.margin)
        .padding(.vertical, DSLayout.spacing)
    }

    /// The league's market list, or a loading/empty/error placeholder.
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            StateView(.loading).frame(maxHeight: .infinity)
        case .failed(let message):
            StateView(.error(message)).frame(maxHeight: .infinity)
        case .loaded:
            if viewModel.visibleEvents.isEmpty {
                StateView(.empty).frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: DSLayout.spacing) {
                        ForEach(viewModel.visibleEvents) { event in
                            NavigationLink(value: event) {
                                HomeCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DSLayout.margin)
                    .padding(.vertical, DSLayout.spacing)
                }
                .refreshable { await viewModel.refresh() }
            }
        }
    }
}
